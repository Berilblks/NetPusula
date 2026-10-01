using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using NetPusula.Application.Auth;
using NetPusula.Application.Exams;
using NetPusula.Application.MockExams;
using NetPusula.Application.Preparations;
using NetPusula.Domain;
namespace NetPusula.Tests;

public sealed class MockExamTests
{
    private static readonly Guid Ales = Guid.Parse("00000000-0000-0000-0000-000000000003");
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { NumberHandling = System.Text.Json.Serialization.JsonNumberHandling.AllowReadingFromString };
    private static async Task Setup(HttpClient client, bool preparation = true, string email = "mock@example.test")
    {
        var response = await client.PostAsJsonAsync("/api/auth/register", new { displayName = "Test", email, password = "Example password 42" });
        response.EnsureSuccessStatusCode();
        var auth = (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        if (preparation) (await client.PostAsJsonAsync("/api/user-exams", new CreatePreparationRequest(Ales, 80, DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30))))).EnsureSuccessStatusCode();
    }
    private static async Task<SaveMockExamRequest> Request(HttpClient client)
    {
        var sections = (await client.GetFromJsonAsync<List<ExamSectionDto>>($"/api/exams/{Ales}/sections"))!;
        return new("Deneme", DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-1)), "Not", sections.Select(s => new MockResultRequest(s.Id, 42, 6)).ToList());
    }
    private static async Task<MockDetailDto> Create(HttpClient client, SaveMockExamRequest? request = null)
    {
        var response = await client.PostAsJsonAsync("/api/mock-exams", request ?? await Request(client));
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.True(response.Headers.CacheControl?.NoStore);
        return (await response.Content.ReadFromJsonAsync<MockDetailDto>(Json))!;
    }
    [Fact] public async Task All_routes_require_authentication()
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); var id = Guid.NewGuid();
        foreach (var response in new[] { await c.GetAsync("/api/mock-exams"), await c.GetAsync($"/api/mock-exams/{id}"), await c.DeleteAsync($"/api/mock-exams/{id}"), await c.PostAsJsonAsync("/api/mock-exams", new {}), await c.PutAsJsonAsync($"/api/mock-exams/{id}", new {}) })
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    [Fact] public async Task Create_derives_ownership_blanks_and_decimal_nets()
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c); var dto = await Create(c);
        Assert.Equal(81m, dto.TotalNet); Assert.All(dto.Results, r => { Assert.Equal(2, r.BlankCount); Assert.Equal(40.5m, r.Net); Assert.NotEmpty(r.SectionName); });
        await using var db = f.CreateDatabase(); var mock = await db.MockExams.SingleAsync(); Assert.Equal((await db.UserExams.SingleAsync()).Id, mock.UserExamId);
        var raw = await c.GetStringAsync($"/api/mock-exams/{dto.Id}"); Assert.DoesNotContain("userId", raw); Assert.DoesNotContain("penaltyDivisor", raw); Assert.Contains("\"totalNet\":\"81", raw);
    }
    [Theory][InlineData("userId")][InlineData("userExamId")][InlineData("net")][InlineData("totalNet")]
    public async Task Mass_assignment_is_rejected(string field)
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c);
        var body = JsonSerializer.SerializeToNode(await Request(c), Json)!.AsObject(); body[field] = "injected";
        Assert.Equal(HttpStatusCode.BadRequest, (await c.PostAsJsonAsync("/api/mock-exams", body)).StatusCode);
    }
    [Fact] public async Task Section_net_injection_is_rejected()
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c);
        var body = JsonSerializer.SerializeToNode(await Request(c), Json)!.AsObject(); body["results"]![0]!["net"] = 999;
        Assert.Equal(HttpStatusCode.BadRequest, (await c.PostAsJsonAsync("/api/mock-exams", body)).StatusCode);
    }
    [Theory][InlineData(-1,0,null)][InlineData(51,0,null)][InlineData(40,11,null)][InlineData(42,6,3)][InlineData(42,6,-1)][InlineData(int.MaxValue,int.MaxValue,null)]
    public async Task Invalid_counts_roll_back_entire_aggregate(int correct, int wrong, int? blank)
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c); var request = await Request(c);
        request.Results![1] = request.Results[1] with { CorrectCount = correct, WrongCount = wrong, BlankCount = blank };
        Assert.Equal(HttpStatusCode.BadRequest, (await c.PostAsJsonAsync("/api/mock-exams", request)).StatusCode);
        await using var db = f.CreateDatabase(); Assert.Empty(await db.MockExams.ToListAsync()); Assert.Empty(await db.MockExamResults.ToListAsync());
    }
    [Theory][InlineData("duplicate")][InlineData("missing")][InlineData("foreign")][InlineData("inactive")]
    public async Task Invalid_section_sets_are_rejected(string kind)
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c); var request = await Request(c);
        if (kind == "duplicate") request.Results![1] = request.Results[0];
        if (kind == "missing") request.Results!.RemoveAt(1);
        if (kind == "foreign") {
            await using var db = f.CreateDatabase(); var exam = new Exam("OTHER", "Other"); var section = new ExamSection(exam,"OTHER","Other",50,4); db.AddRange(exam,section); await db.SaveChangesAsync(); request.Results![1] = request.Results[1] with { ExamSectionId = section.Id };
        }
        if (kind == "inactive") { await using var db = f.CreateDatabase(); (await db.ExamSections.SingleAsync(s => s.Id == request.Results![1].ExamSectionId)).Deactivate(); await db.SaveChangesAsync(); }
        Assert.Equal(HttpStatusCode.BadRequest, (await c.PostAsJsonAsync("/api/mock-exams", request)).StatusCode);
    }
    [Theory][InlineData("future")][InlineData("missingDate")][InlineData("name")][InlineData("longName")][InlineData("notes")][InlineData("nullResults")]
    public async Task General_validation(string kind)
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c); var r = await Request(c);
        r = kind switch { "future" => r with {TakenAt=DateOnly.FromDateTime(DateTime.UtcNow.AddDays(2))}, "missingDate" => r with {TakenAt=default}, "name"=>r with {Name=" "}, "longName"=>r with {Name=new string('x',201)}, "notes"=>r with {Notes=new string('x',4001)}, _=>r with {Results=null} };
        Assert.Equal(HttpStatusCode.BadRequest, (await c.PostAsJsonAsync("/api/mock-exams", r)).StatusCode);
    }
    [Fact] public async Task Fractional_counts_are_rejected()
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c);
        var body=JsonSerializer.SerializeToNode(await Request(c),Json)!;body["results"]![0]!["correctCount"]=1.5;
        Assert.Equal(HttpStatusCode.BadRequest,(await c.PostAsJsonAsync("/api/mock-exams",body)).StatusCode);
    }
    [Fact] public async Task No_preparation_is_explicit_and_not_found_does_not_leak()
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c,false);
        foreach(var response in new[]{await c.GetAsync("/api/mock-exams"),await c.PostAsJsonAsync("/api/mock-exams",await Request(c))}) { Assert.Equal(HttpStatusCode.Conflict,response.StatusCode); Assert.Contains("active_preparation_required",await response.Content.ReadAsStringAsync()); }
        Assert.Equal(HttpStatusCode.NotFound,(await c.GetAsync($"/api/mock-exams/{Guid.NewGuid()}")).StatusCode);
    }
    [Fact] public async Task History_is_paginated_newest_first_and_active_only()
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c); var r = await Request(c);
        var old = await Create(c,r with { TakenAt = r.TakenAt.AddDays(-2) }); var newest=await Create(c,r); await Create(c,r with {TakenAt=r.TakenAt.AddDays(-1)});
        var page=(await c.GetFromJsonAsync<MockPageDto>("/api/mock-exams?page=1&pageSize=2",Json))!;
        Assert.Equal(3,page.TotalCount);Assert.Equal(2,page.TotalPages);Assert.Equal(newest.Id,page.Items[0].Id);Assert.Equal(2,page.Items.Count);
        Assert.Equal(old.Id,(await c.GetFromJsonAsync<MockPageDto>("/api/mock-exams?page=2&pageSize=2",Json))!.Items.Single().Id);
        await c.PostAsJsonAsync("/api/user-exams",new CreatePreparationRequest(Ales,81,DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30))));
        Assert.Empty((await c.GetFromJsonAsync<MockPageDto>("/api/mock-exams",Json))!.Items);
        Assert.Equal(HttpStatusCode.OK,(await c.GetAsync($"/api/mock-exams/{old.Id}")).StatusCode);
    }
    [Theory][InlineData(0,20)][InlineData(1,101)][InlineData(1,0)][InlineData(int.MaxValue,100)]
    public async Task Pagination_limits(int page,int size)
    {
        await using var f = new AuthApiFactory(); using var c = f.CreateClient(); await Setup(c);
        Assert.Equal(HttpStatusCode.BadRequest,(await c.GetAsync($"/api/mock-exams?page={page}&pageSize={size}")).StatusCode);
    }
    [Fact] public async Task Foreign_user_cannot_read_edit_delete_or_list()
    {
        await using var f = new AuthApiFactory(); using var a=f.CreateClient();using var b=f.CreateClient();await Setup(a);var row=await Create(a);await Setup(b,true,"other@example.test");
        Assert.Equal(HttpStatusCode.NotFound,(await b.GetAsync($"/api/mock-exams/{row.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,(await b.PutAsJsonAsync($"/api/mock-exams/{row.Id}",await Request(b))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,(await b.DeleteAsync($"/api/mock-exams/{row.Id}")).StatusCode);
        Assert.Empty((await b.GetFromJsonAsync<MockPageDto>("/api/mock-exams",Json))!.Items);
    }
    [Fact] public async Task Edit_preserves_snapshot_rules_and_display_after_catalogue_changes()
    {
        await using var f = new AuthApiFactory(); using var c=f.CreateClient();await Setup(c);var row=await Create(c);
        await using(var db=f.CreateDatabase()) {
            foreach(var section in await db.ExamSections.Where(s=>s.ExamId==Ales).ToListAsync()) {section.ConfigureScoring(10,2);section.Deactivate();db.Entry(section).Property(s=>s.Name).CurrentValue="Changed";}
            await db.SaveChangesAsync();
        }
        var before=(await c.GetFromJsonAsync<MockDetailDto>($"/api/mock-exams/{row.Id}",Json))!;Assert.Equal(81,before.TotalNet);Assert.DoesNotContain(before.Results,r=>r.SectionName=="Changed");
        var request=new SaveMockExamRequest("Edited",row.TakenAt,null,row.Results.Select(r=>new MockResultRequest(r.ExamSectionId,40,8)).ToList());
        var response=await c.PutAsJsonAsync($"/api/mock-exams/{row.Id}",request);response.EnsureSuccessStatusCode();var after=(await response.Content.ReadFromJsonAsync<MockDetailDto>(Json))!;
        Assert.Equal(76,after.TotalNet);Assert.Equal("Edited",after.Name);Assert.All(after.Results,r=>{Assert.Equal(50,r.QuestionCount);Assert.Equal(2,r.BlankCount);Assert.Equal(38,r.Net);});
    }
    [Fact] public async Task Delete_removes_only_intended_aggregate_and_retains_configuration()
    {
        await using var f = new AuthApiFactory();using var c=f.CreateClient();await Setup(c);var a=await Create(c);var b=await Create(c);
        Assert.Equal(HttpStatusCode.NoContent,(await c.DeleteAsync($"/api/mock-exams/{a.Id}")).StatusCode);
        await using var db=f.CreateDatabase();Assert.Equal(b.Id,(await db.MockExams.SingleAsync()).Id);Assert.Equal(2,await db.MockExamResults.CountAsync());Assert.Single(await db.UserExams.ToListAsync());Assert.Equal(2,await db.ExamSections.CountAsync(s=>s.ExamId==Ales));
        Assert.Equal(HttpStatusCode.NotFound,(await c.DeleteAsync($"/api/mock-exams/{a.Id}")).StatusCode);
    }

    [Fact] public async Task Database_failure_does_not_leave_partial_create_or_delete()
    {
        await using var f = new AuthApiFactory();using var c=f.CreateClient();await Setup(c);
        await using(var db=f.CreateDatabase()) await db.Database.ExecuteSqlRawAsync("CREATE TRIGGER FailResult BEFORE INSERT ON MockExamResults BEGIN SELECT RAISE(ABORT, 'test failure'); END;");
        var response=await c.PostAsJsonAsync("/api/mock-exams",await Request(c));Assert.Equal(HttpStatusCode.InternalServerError,response.StatusCode);Assert.DoesNotContain("test failure",await response.Content.ReadAsStringAsync());
        await using(var db=f.CreateDatabase()) {Assert.Equal(0,await db.MockExams.CountAsync());Assert.Equal(0,await db.MockExamResults.CountAsync());await db.Database.ExecuteSqlRawAsync("DROP TRIGGER FailResult;");}
        var row=await Create(c);
        await using(var db=f.CreateDatabase()) await db.Database.ExecuteSqlRawAsync("CREATE TRIGGER FailDelete BEFORE DELETE ON MockExams BEGIN SELECT RAISE(ABORT, 'test failure'); END;");
        Assert.Equal(HttpStatusCode.InternalServerError,(await c.DeleteAsync($"/api/mock-exams/{row.Id}")).StatusCode);
        await using(var db=f.CreateDatabase()) {Assert.Equal(1,await db.MockExams.CountAsync());Assert.Equal(2,await db.MockExamResults.CountAsync());}
    }
    [Fact] public async Task Invalid_edit_keeps_original_counts_and_metadata()
    {
        await using var f = new AuthApiFactory();using var c=f.CreateClient();await Setup(c);var row=await Create(c);var request=await Request(c);
        request.Results![1]=request.Results[1] with {CorrectCount=99};
        Assert.Equal(HttpStatusCode.BadRequest,(await c.PutAsJsonAsync($"/api/mock-exams/{row.Id}",request with {Name="Invalid change"})).StatusCode);
        var after=(await c.GetFromJsonAsync<MockDetailDto>($"/api/mock-exams/{row.Id}",Json))!;Assert.Equal(row.Name,after.Name);Assert.Equal(row.TotalNet,after.TotalNet);
    }
}
