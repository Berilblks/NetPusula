using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using NetPusula.Application.Auth;
using NetPusula.Application.Statistics;
using NetPusula.Application.Preparations;
using NetPusula.Domain;
namespace NetPusula.Tests;

public sealed class StatisticsTests
{
    private static readonly Guid Ales=Guid.Parse("00000000-0000-0000-0000-000000000003");
    private static async Task<Guid> Setup(HttpClient c,bool prepare=true,string email="statistics@example.test")
    {
        var response=await c.PostAsJsonAsync("/api/auth/register",new {displayName="Statistics",email,password="Example password 42"});response.EnsureSuccessStatusCode();
        var auth=(await response.Content.ReadFromJsonAsync<AuthResponse>())!;
        c.DefaultRequestHeaders.Authorization=new AuthenticationHeaderValue("Bearer",auth.AccessToken);
        if(prepare) (await c.PostAsJsonAsync("/api/user-exams",new CreatePreparationRequest(Ales,80,DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30))))).EnsureSuccessStatusCode();
        return auth.User.Id;
    }
    private static async Task<StatisticsDto> Get(HttpClient c,string range="all")
    {
        var response=await c.GetAsync("/api/statistics?range="+range);response.EnsureSuccessStatusCode();Assert.True(response.Headers.CacheControl?.NoStore);
        return (await response.Content.ReadFromJsonAsync<StatisticsDto>())!;
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
    [Fact] public async Task Authentication_required() {await using var f=new AuthApiFactory();using var c=f.CreateClient();Assert.Equal(HttpStatusCode.Unauthorized,(await c.GetAsync("/api/statistics")).StatusCode);}
    [Fact] public async Task Active_preparation_required() {await using var f=new AuthApiFactory();using var c=f.CreateClient();await Setup(c,false);var r=await c.GetAsync("/api/statistics");Assert.Equal(HttpStatusCode.Conflict,r.StatusCode);Assert.Contains("active_preparation_required",await r.Content.ReadAsStringAsync());}
    [Fact] public async Task Zero_has_nulls_not_fake_zero()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();await Setup(c);var d=await Get(c);
        Assert.Equal(new StatisticsSummary(0,null,null,null,null),d.Summary);Assert.Empty(d.Series);Assert.Null(d.BestMock);Assert.False(d.Improvement.SufficientData);
        Assert.Null(d.Activity.FirstMockDate);Assert.Null(d.Activity.LastMockDate);Assert.Null(d.Activity.AverageDaysBetweenMocks);
        Assert.Equal(2,d.Sections.Count);Assert.All(d.Sections,s=>{Assert.Null(s.AverageNet);Assert.Null(s.WorstNet);Assert.Null(s.Answers.Correct);Assert.Empty(s.Series);});
    }
    [Theory][InlineData(0)][InlineData(25)][InlineData(50)] public async Task One_attempt(int correct)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,correct);var d=await Get(c);
        Assert.Equal(new StatisticsSummary(1,correct*2,correct*2,correct*2,correct*2),d.Summary);Assert.Single(d.Series);Assert.Equal(ids[0],d.BestMock!.MockExamId);
        Assert.Null(d.Activity.AverageDaysBetweenMocks);Assert.Equal(d.Activity.FirstMockDate,d.Activity.LastMockDate);Assert.False(d.Improvement.SufficientData);
    }
    [Theory][InlineData("5",5)][InlineData("10",10)][InlineData("20",20)][InlineData("all",25)]
    public async Task Range_consistently_limits_every_aggregate(string range,int count)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,Enumerable.Range(1,25).ToArray());var d=await Get(c,range);
        Assert.Equal(count,d.Summary.AttemptCount);Assert.Equal(25,d.Range.AvailableAttemptCount);Assert.False(d.Range.IsCapped);Assert.Equal(ids.TakeLast(count),d.Series.Select(p=>p.MockExamId));
        Assert.Equal(50,d.Summary.LatestNet);Assert.Equal(50,d.Summary.BestNet);Assert.Equal((26-count)*2,d.Summary.WorstNet);Assert.Equal(51-count,d.Summary.AverageNet);
        Assert.Equal(count,d.Activity.AttemptCount);Assert.Equal(1,d.Activity.AverageDaysBetweenMocks);
        Assert.All(d.Sections,s=>{Assert.Equal(count,s.AttemptCount);Assert.Equal(count,s.Series.Count);Assert.Equal((51m-count)/2,s.AverageNet);Assert.Equal((51m-count)/2,s.Answers.Correct);Assert.Equal(0,s.Answers.Wrong);Assert.Equal(50-(51m-count)/2,s.Answers.Blank);});
        Assert.Equal(count>=6,d.Improvement.SufficientData);Assert.Equal(count>=6,d.Sections[0].Improvement.SufficientData);
    }
    [Theory][InlineData(500,false)][InlineData(501,true)] public async Task All_cap_is_explicit_and_applies_to_aggregates(int count,bool capped)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,Enumerable.Range(0,count).Select(i=>i==0?50:10).ToArray());var d=await Get(c);
        Assert.Equal(500,d.Range.Limit);Assert.Equal(capped,d.Range.IsCapped);Assert.Equal(count,d.Range.AvailableAttemptCount);Assert.Equal(500,d.Summary.AttemptCount);Assert.Equal(ids.TakeLast(500),d.Series.Select(p=>p.MockExamId));Assert.Equal(capped?20:100,d.Summary.BestNet);
    }
    [Fact] public async Task Default_is_twenty() {await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,Enumerable.Repeat(1,21).ToArray());var d=(await c.GetFromJsonAsync<StatisticsDto>("/api/statistics"))!;Assert.Equal("20",d.Range.Selection);Assert.Equal(20,d.Summary.AttemptCount);}
    [Theory][InlineData("")][InlineData("0")][InlineData("6")][InlineData("ALL")][InlineData("-1")][InlineData("5&range=10")]
    public async Task Invalid_range_rejected(string range) {await using var f=new AuthApiFactory();using var c=f.CreateClient();await Setup(c);Assert.Equal(HttpStatusCode.BadRequest,(await c.GetAsync("/api/statistics?range="+range)).StatusCode);}
    [Theory][InlineData("userId")][InlineData("userExamId")]
    public async Task Arbitrary_scope_rejected(string name) {await using var f=new AuthApiFactory();using var c=f.CreateClient();await Setup(c);Assert.Equal(HttpStatusCode.BadRequest,(await c.GetAsync($"/api/statistics?{name}={Guid.NewGuid()}")).StatusCode);}
    [Fact] public async Task Other_user_and_old_preparation_excluded()
    {
        await using var f=new AuthApiFactory();using var a=f.CreateClient();using var b=f.CreateClient();var ua=await Setup(a);var ub=await Setup(b,true,"other@example.test");await Add(f,ua,40);await Add(f,ub,50);
        (await a.PostAsJsonAsync("/api/user-exams",new CreatePreparationRequest(Ales,81,DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30))))).EnsureSuccessStatusCode();await Add(f,ua,10);
        var d=await Get(a);Assert.Equal(1,d.Range.AvailableAttemptCount);Assert.Equal(20,d.Summary.AverageNet);Assert.All(d.Sections,s=>Assert.Equal(1,s.AttemptCount));
        await using var db=f.CreateDatabase();Assert.Equal(3,await db.MockExams.CountAsync());
    }
    [Fact] public async Task Taken_date_controls_latest_and_best_ties()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,40,40,20);
        await using(var db=f.CreateDatabase()){var m=await db.MockExams.SingleAsync(m=>m.Id==ids[0]);m.Update(m.Name,DateTime.UtcNow.Date,null);await db.SaveChangesAsync();}
        var d=await Get(c);Assert.Equal(ids[0],d.Series[^1].MockExamId);Assert.Equal(ids[0],d.BestMock!.MockExamId);Assert.Equal(80,d.Summary.LatestNet);Assert.Equal(40,d.Summary.WorstNet);
    }
    [Theory][InlineData(false)][InlineData(true)] public async Task Same_date_order_created_then_id_and_zero_intervals(bool sameCreated)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,20,20);
        await using(var db=f.CreateDatabase()) {
            foreach(var m in await db.MockExams.ToListAsync())m.Update(m.Name,DateTime.UtcNow.Date,null);await db.SaveChangesAsync();var time=DateTime.UtcNow.AddDays(-1);
            for(var i=0;i<ids.Count;i++) await db.Database.ExecuteSqlInterpolatedAsync($"UPDATE \"MockExams\" SET \"CreatedAtUtc\"={time.AddMinutes(sameCreated?0:i)} WHERE \"Id\"={ids[i]}");
        }
        var d=await Get(c);var expected=sameCreated?ids.OrderBy(x=>x).ToList():ids;Assert.Equal(expected,d.Series.Select(p=>p.MockExamId));Assert.Equal(expected[^1],d.BestMock!.MockExamId);Assert.Equal(0,d.Activity.AverageDaysBetweenMocks);
    }
    [Theory][InlineData(5)][InlineData(6)][InlineData(9)] public async Task Short_term_comparison_uses_same_six_values_as_dashboard(int count)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,Enumerable.Range(1,count).ToArray());var d=await Get(c);
        var dashboard=(await c.GetFromJsonAsync<NetPusula.Application.Dashboard.DashboardDto>("/api/dashboard"))!;Assert.Equal(StatisticsComparison.From(dashboard.Improvement),d.Improvement);
        Assert.Equal(count>=6,d.Improvement.SufficientData);
        if(count<6){Assert.Null(d.Improvement.Change);Assert.Null(d.Sections[0].Improvement.Change);}else{Assert.Equal(6,d.Improvement.Change);Assert.Equal(3,d.Sections[0].Improvement.Change);Assert.Equal(count-1,d.Sections[0].Improvement.RecentAverage);Assert.Equal(count-4,d.Sections[0].Improvement.PreviousAverage);}
    }
    [Fact] public async Task Negative_change_is_neutral_data() {await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,30,30,30,20,20,20);var d=await Get(c);Assert.Equal(-20,d.Improvement.Change);Assert.All(d.Sections,s=>Assert.Equal(-10,s.Improvement.Change));}
    [Theory][InlineData(3)][InlineData(4)][InlineData(8)] public async Task Decimal_negative_net_and_answer_averages_use_snapshots(int divisor)
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);
        await using(var db=f.CreateDatabase()) {
            var p=await db.UserExams.SingleAsync(x=>x.UserId==user);var s=await db.ExamSections.FirstAsync();s.ConfigureScoring(50,divisor);
            for(var i=0;i<2;i++){var m=new MockExam(p,"Decimal",DateTime.UtcNow.Date.AddDays(-1+i));db.AddRange(m,new MockExamResult(m,s,0,1+i,49-i));}await db.SaveChangesAsync();s.ConfigureScoring(20,2);await db.SaveChangesAsync();
        }
        var d=await Get(c);var expected=(-1m/divisor-2m/divisor)/2;
        Assert.Equal(expected,d.Summary.AverageNet);Assert.Equal(-1m/divisor,d.Summary.BestNet);Assert.Equal(-2m/divisor,d.Summary.WorstNet);Assert.Equal(-2m/divisor,d.Summary.LatestNet);
        var s2=d.Sections.Single(s=>s.AttemptCount==2);Assert.Equal(expected,s2.AverageNet);Assert.Equal(1.5m,s2.Answers.Wrong);Assert.Equal(48.5m,s2.Answers.Blank);Assert.Equal(0,s2.Answers.Correct);
        Assert.Equal(new[]{1,2},s2.Series.Select(p=>p.WrongCount));Assert.Null(d.Sections.Single(s=>s.AttemptCount==0).AverageNet);
    }
    [Fact] public async Task Stable_identity_groups_and_missing_results_are_not_zero_filled()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,10,20,30,40,45,50);Guid sid;
        await using(var db=f.CreateDatabase()) {
            var s=await db.ExamSections.FirstAsync();sid=s.Id;db.Entry(s).Property(x=>x.Name).CurrentValue="Renamed";
            db.Remove(await db.MockExamResults.SingleAsync(r=>r.MockExamId==ids[ids.Count-1] && r.ExamSectionId==sid));
            var exam=await db.Exams.SingleAsync(e=>e.Id==Ales);db.Add(new ExamSection(exam,"NEW","New",10,4,groupCode:"GROUP",groupName:"Group"));await db.SaveChangesAsync();
        }
        var d=await Get(c);var section=d.Sections.Single(s=>s.ExamSectionId==sid);Assert.Equal("Renamed",section.SectionName);Assert.Equal(5,section.AttemptCount);Assert.Equal(45,section.LatestNet);Assert.Equal(29,section.AverageNet);Assert.Equal(10,section.WorstNet);Assert.Equal(45,section.BestNet);Assert.False(section.Improvement.SufficientData);
        Assert.Equal(ids.Take(5),section.Series.Select(p=>p.MockExamId));var added=d.Sections.Single(s=>s.SectionCode=="NEW");Assert.Equal("GROUP",added.GroupCode);Assert.Equal("Group",added.GroupName);Assert.Null(added.Answers.Correct);Assert.Empty(added.Series);
    }
    [Fact] public async Task Inactive_section_keeps_snapshot_identity_and_display()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,20);Guid id;string name;
        await using(var db=f.CreateDatabase()){var s=await db.ExamSections.FirstAsync();id=s.Id;name=s.Name;s.Deactivate();db.Entry(s).Property(x=>x.Name).CurrentValue="Changed";await db.SaveChangesAsync();}
        var s2=(await Get(c)).Sections.Single(s=>s.ExamSectionId==id);Assert.False(s2.IsActive);Assert.Equal(name,s2.SectionName);Assert.Equal(20,s2.LatestNet);
    }
    [Fact] public async Task Activity_averages_intervals_including_same_day()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);var ids=await Add(f,user,10,20,30);
        var today=DateTime.UtcNow.Date;
        await using(var db=f.CreateDatabase()){for(var i=0;i<3;i++){var m=await db.MockExams.SingleAsync(m=>m.Id==ids[i]);m.Update(m.Name,today.AddDays(i==0?-3:0),null);}await db.SaveChangesAsync();}
        var d=await Get(c);Assert.Equal(DateOnly.FromDateTime(today.AddDays(-3)),d.Activity.FirstMockDate);Assert.Equal(DateOnly.FromDateTime(today),d.Activity.LastMockDate);Assert.Equal(1.5m,d.Activity.AverageDaysBetweenMocks);
    }
    [Fact] public async Task Safe_DTO_and_decimal_strings_in_every_nested_structure()
    {
        await using var f=new AuthApiFactory();using var c=f.CreateClient();var user=await Setup(c);await Add(f,user,1,2,3,4,5,6);var raw=await c.GetStringAsync("/api/statistics");using var doc=JsonDocument.Parse(raw);
        var root=doc.RootElement;Assert.Equal(JsonValueKind.String,root.GetProperty("targetNet").ValueKind);
        foreach(var key in new[]{"latestNet","averageNet","bestNet","worstNet"})Assert.Equal(JsonValueKind.String,root.GetProperty("summary").GetProperty(key).ValueKind);
        Assert.Equal(JsonValueKind.Number,root.GetProperty("summary").GetProperty("attemptCount").ValueKind);
        Assert.Equal(JsonValueKind.String,root.GetProperty("sections")[0].GetProperty("series")[0].GetProperty("net").ValueKind);
        Assert.Equal(JsonValueKind.String,root.GetProperty("sections")[0].GetProperty("answers").GetProperty("correct").ValueKind);
        Assert.Equal(JsonValueKind.String,root.GetProperty("improvement").GetProperty("change").ValueKind);
        Assert.Equal(JsonValueKind.String,root.GetProperty("activity").GetProperty("averageDaysBetweenMocks").ValueKind);
        foreach(var field in new[]{"userId","userExamId","password","tokenHash","penaltyDivisor","snapshot"})Assert.DoesNotContain(field,raw,StringComparison.OrdinalIgnoreCase);
    }
}
