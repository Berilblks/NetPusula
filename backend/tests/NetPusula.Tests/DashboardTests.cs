using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using NetPusula.Application.Auth;
using NetPusula.Application.Dashboard;
using NetPusula.Application.Preparations;
using NetPusula.Domain;
namespace NetPusula.Tests;
public sealed class DashboardTests
{
    private static readonly Guid Ales=Guid.Parse("00000000-0000-0000-0000-000000000003");
    private static async Task<Guid> Setup(HttpClient c,bool prepare=true,string email="dashboard@example.test",decimal target=80)
    {
        var response=await c.PostAsJsonAsync("/api/auth/register",new {displayName="Dashboard",email,password="Example password 42"});response.EnsureSuccessStatusCode();
        var auth=(await response.Content.ReadFromJsonAsync<AuthResponse>())!;c.DefaultRequestHeaders.Authorization=new AuthenticationHeaderValue("Bearer",auth.AccessToken);
        if(prepare) (await c.PostAsJsonAsync("/api/user-exams",new CreatePreparationRequest(Ales,target,DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30))))).EnsureSuccessStatusCode();
        return auth.User.Id;
    }
    private static async Task<DashboardDto> Get(HttpClient c)
    {
        var response=await c.GetAsync("/api/dashboard");response.EnsureSuccessStatusCode();Assert.True(response.Headers.CacheControl?.NoStore);
        return (await response.Content.ReadFromJsonAsync<DashboardDto>())!;
    }
    private static async Task<List<Guid>> Add(AuthApiFactory f,Guid user,params int[] correct)
    {
        await using var db=f.CreateDatabase();var prep=await db.UserExams.SingleAsync(p=>p.UserId==user && p.IsActive);
        var sections=await db.ExamSections.Where(s=>s.ExamId==Ales && s.IsActive).OrderBy(s=>s.Code).ToListAsync();var ids=new List<Guid>();
        for(var i=0;i<correct.Length;i++) {
            var mock=new MockExam(prep,"Attempt "+i,DateTime.UtcNow.Date.AddDays(-correct.Length+i));ids.Add(mock.Id);db.Add(mock);
            foreach(var s in sections) db.Add(new MockExamResult(mock,s,correct[i],0,s.QuestionCount-correct[i]));
        }
        await db.SaveChangesAsync();return ids;
    }
    [Fact] public async Task Authentication_required() { await using var f=new AuthApiFactory();using var c=f.CreateClient();Assert.Equal(HttpStatusCode.Unauthorized,(await c.GetAsync("/api/dashboard")).StatusCode); }
    [Fact] public async Task Explicit_no_preparation() { await using var f=new AuthApiFactory();using var c=f.CreateClient();await Setup(c,false);var r=await c.GetAsync("/api/dashboard");Assert.Equal(HttpStatusCode.Conflict,r.StatusCode);Assert.Contains("active_preparation_required",await r.Content.ReadAsStringAsync()); }
    [Fact] public async Task Empty_is_not_zero_and_current_sections_are_present()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();await Setup(c);var d=await Get(c);
        Assert.Equal(0,d.Summary.MockExamCount);Assert.Null(d.Summary.LatestNet);Assert.Null(d.Summary.AverageNet);Assert.Null(d.Summary.BestNet);Assert.Null(d.Summary.TargetDifference);Assert.Empty(d.Trend);Assert.Empty(d.RecentMocks);
        Assert.Equal(2,d.Sections.Count);Assert.All(d.Sections,s=>{Assert.Equal(0,s.AttemptCount);Assert.Null(s.LatestNet);Assert.Null(s.AverageNet);Assert.Null(s.BestNet);});Assert.False(d.Improvement.HasEnoughData);
    }
    [Theory][InlineData(30,60,20)][InlineData(40,80,0)][InlineData(45,90,-10)][InlineData(0,0,80)]
    public async Task One_mock_and_signed_target_difference(int correct,int net,int remaining)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,correct);var d=await Get(c);
        Assert.Equal(1,d.Summary.MockExamCount);Assert.Equal(net,d.Summary.LatestNet);Assert.Equal(net,d.Summary.AverageNet);Assert.Equal(net,d.Summary.BestNet);Assert.Equal(remaining,d.Summary.TargetDifference);Assert.Single(d.Trend);Assert.False(d.Improvement.HasEnoughData);
    }
    [Fact] public async Task Multiple_average_best_latest_and_sections()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,20,40,30);var d=await Get(c);
        Assert.Equal(60,d.Summary.LatestNet);Assert.Equal(60,d.Summary.AverageNet);Assert.Equal(80,d.Summary.BestNet);
        Assert.All(d.Sections,s=>{Assert.Equal(3,s.AttemptCount);Assert.Equal(30,s.LatestNet);Assert.Equal(30,s.AverageNet);Assert.Equal(40,s.BestNet);});
    }
    [Fact] public async Task Other_user_and_inactive_preparation_excluded_even_with_query_injection()
    {
        await using var f=new AuthApiFactory();using var a=f.CreateClient();using var b=f.CreateClient();var ua=await Setup(a);var ub=await Setup(b,true,"other@example.test");await Add(f,ua,40);await Add(f,ub,50);
        var old=(await Get(a)).Preparation.Id;
        (await a.PostAsJsonAsync("/api/user-exams",new CreatePreparationRequest(Ales,81,DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30))))).EnsureSuccessStatusCode();await Add(f,ua,10);
        var d=(await a.GetFromJsonAsync<DashboardDto>($"/api/dashboard?userId={ub}&userExamId={old}"))!;Assert.Equal(1,d.Summary.MockExamCount);Assert.Equal(20,d.Summary.AverageNet);Assert.NotEqual(old,d.Preparation.Id);
        await using var db=f.CreateDatabase();Assert.Equal(3,await db.MockExams.CountAsync());
    }
    [Fact] public async Task Latest_uses_taken_date_not_insert_order()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,10,30);
        await using(var db=f.CreateDatabase()){var row=await db.MockExams.SingleAsync(m=>m.Id==ids[0]);row.Update("Newer date",DateTime.UtcNow.Date,null);await db.SaveChangesAsync();}
        var d=await Get(c);Assert.Equal(20,d.Summary.LatestNet);Assert.Equal(ids[0],d.RecentMocks[0].MockExamId);Assert.Equal(ids[0],d.Trend[^1].MockExamId);
    }
    [Theory][InlineData(false)][InlineData(true)]
    public async Task Same_date_created_time_then_id_tiebreak(bool sameCreated)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,10,30);
        await using(var db=f.CreateDatabase()) {
            foreach(var m in await db.MockExams.ToListAsync()) {m.Update(m.Name,DateTime.UtcNow.Date,null);}await db.SaveChangesAsync();
            var time=DateTime.UtcNow.AddDays(-1);
            for(var i=0;i<ids.Count;i++) await db.Database.ExecuteSqlInterpolatedAsync($"UPDATE \"MockExams\" SET \"CreatedAtUtc\"={time.AddMinutes(sameCreated?0:i)} WHERE \"Id\"={ids[i]}");
        }
        var d=await Get(c);var expected=sameCreated?ids.OrderBy(x=>x).Last():ids[1];Assert.Equal(expected,d.RecentMocks[0].MockExamId);Assert.Equal(expected,d.Trend[^1].MockExamId);
    }
    [Theory][InlineData(1)][InlineData(5)][InlineData(6)][InlineData(7)][InlineData(25)]
    public async Task Trend_recent_and_improvement_windows(int count)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,Enumerable.Range(1,count).ToArray());var d=await Get(c);
        Assert.Equal(Math.Min(20,count),d.Trend.Count);Assert.Equal(ids.TakeLast(20),d.Trend.Select(x=>x.MockExamId));Assert.Equal(ids.AsEnumerable().Reverse().Take(3),d.RecentMocks.Select(x=>x.MockExamId));
        Assert.Equal(count>=6,d.Improvement.HasEnoughData);
        if(count<6) {Assert.Null(d.Improvement.Change);Assert.Null(d.Improvement.RecentAverage);Assert.Null(d.Improvement.PreviousAverage);}
        else {Assert.Equal((count-1)*2,d.Improvement.RecentAverage);Assert.Equal((count-4)*2,d.Improvement.PreviousAverage);Assert.Equal(6,d.Improvement.Change);}
    }
    [Fact] public async Task Improvement_can_be_negative()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,30,30,30,20,20,20);Assert.Equal(-20,(await Get(c)).Improvement.Change);
    }
    [Fact] public async Task Stable_identity_current_display_and_missing_new_section()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,20,30);
        Guid id;
        await using(var db=f.CreateDatabase()) {
            var section=await db.ExamSections.FirstAsync();id=section.Id;db.Entry(section).Property(s=>s.Name).CurrentValue="Renamed";section.ConfigureScoring(10,2);
            var exam=await db.Exams.SingleAsync(e=>e.Id==Ales);db.Add(new ExamSection(exam,"NEW","New section",10,4,groupCode:"GROUP",groupName:"Group"));await db.SaveChangesAsync();
        }
        var d=await Get(c);var existing=d.Sections.Single(s=>s.ExamSectionId==id);Assert.Equal("Renamed",existing.SectionName);Assert.Equal(25,existing.AverageNet);Assert.Equal(30,existing.LatestNet);Assert.Equal(10,existing.QuestionCount);
        var added=d.Sections.Single(s=>s.SectionCode=="NEW");Assert.Equal(0,added.AttemptCount);Assert.Null(added.AverageNet);Assert.Equal("GROUP",added.GroupCode);Assert.Equal("Group",added.GroupName);
    }
    [Fact] public async Task Inactive_section_uses_latest_snapshot_display()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,20);Guid id;string name;
        await using(var db=f.CreateDatabase()){var s=await db.ExamSections.FirstAsync();id=s.Id;name=s.Name;s.Deactivate();db.Entry(s).Property(x=>x.Name).CurrentValue="Changed";await db.SaveChangesAsync();}
        var stat=(await Get(c)).Sections.Single(s=>s.ExamSectionId==id);Assert.False(stat.IsActive);Assert.Equal(name,stat.SectionName);Assert.Equal(20,stat.LatestNet);
    }
    [Theory][InlineData(4)][InlineData(3)][InlineData(8)]
    public async Task Decimal_division_matches_domain_without_premature_rounding(int divisor)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);
        await using(var db=f.CreateDatabase()) {
            var p=await db.UserExams.SingleAsync(x=>x.UserId==user);var s=await db.ExamSections.FirstAsync();s.ConfigureScoring(50,divisor);var m=new MockExam(p,"Decimal",DateTime.UtcNow.Date);db.AddRange(m,new MockExamResult(m,s,0,1,49));await db.SaveChangesAsync();
        }
        var d=await Get(c);Assert.Equal(-1m/divisor,d.Summary.AverageNet);Assert.Equal(d.Summary.AverageNet,d.Summary.BestNet);Assert.Equal(80+1m/divisor,d.Summary.TargetDifference);
        Assert.Single(d.Sections,s=>s.AttemptCount==1);Assert.Single(d.Sections,s=>s.AttemptCount==0);
    }
    [Theory][InlineData(-1,"past",0)][InlineData(0,"today",0)][InlineData(1,"future",1)]
    public async Task Date_status_uses_Turkey_calendar(int offset,string status,int days)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var today=PreparationRules.Today(f.Clock.GetUtcNow());
        await using(var db=f.CreateDatabase()){var p=await db.UserExams.SingleAsync(x=>x.UserId==user);db.Entry(p).Property(x=>x.ExamDate).CurrentValue=today.AddDays(offset);await db.SaveChangesAsync();}
        var d=await Get(c);Assert.Equal(status,d.Preparation.DateStatus);Assert.Equal(days,d.Preparation.DaysRemaining);
    }
    [Fact] public async Task Safe_wire_contract_uses_decimal_strings_and_integer_counts()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,30);
        var raw=await c.GetStringAsync("/api/dashboard");using var doc=System.Text.Json.JsonDocument.Parse(raw);
        Assert.Equal(System.Text.Json.JsonValueKind.String,doc.RootElement.GetProperty("summary").GetProperty("averageNet").ValueKind);Assert.Equal(System.Text.Json.JsonValueKind.Number,doc.RootElement.GetProperty("summary").GetProperty("mockExamCount").ValueKind);
        foreach(var field in new[]{"userId","password","tokenHash","penaltyDivisor","snapshot"})Assert.DoesNotContain(field,raw,StringComparison.OrdinalIgnoreCase);
    }
}
