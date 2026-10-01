using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using NetPusula.Application.Auth;
using NetPusula.Application.Exams;
using NetPusula.Application.Preparations;
using NetPusula.Domain;

namespace NetPusula.Tests;

public sealed class PreparationTests
{
    private static readonly Guid Ales = Guid.Parse("00000000-0000-0000-0000-000000000003");
    private static readonly Guid Yks = Guid.Parse("00000000-0000-0000-0000-000000000001");
    private static DateOnly Future => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30));
    private static async Task<AuthResponse> SignIn(HttpClient client, string email = "preparation@example.test")
    {
        var response = await client.PostAsJsonAsync("/api/auth/register", new { displayName = "Student", email, password = "Example password 42" });
        response.EnsureSuccessStatusCode();
        var auth = (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        return auth;
    }
    private static async Task<PreparationDto> Create(HttpClient client, Guid? exam = null, decimal target = 80)
    {
        var response = await client.PostAsJsonAsync("/api/user-exams", new CreatePreparationRequest(exam ?? Ales, target, Future));
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.True(response.Headers.CacheControl?.NoStore);
        return (await response.Content.ReadFromJsonAsync<PreparationDto>())!;
    }
    [Fact]
    public async Task All_preparation_routes_require_authentication()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/user-exams/active")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/user-exams", new CreatePreparationRequest(Ales, 80, Future))).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PutAsJsonAsync($"/api/user-exams/{Guid.NewGuid()}", new UpdatePreparationRequest(80, Future))).StatusCode);
    }
    [Fact]
    public async Task Create_and_active_use_current_user_and_safe_dto()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); var auth = await SignIn(client);
        Assert.Equal(HttpStatusCode.NoContent, (await client.GetAsync("/api/user-exams/active")).StatusCode);
        var row = await Create(client);
        Assert.Equal("ALES", row.Exam.Code); Assert.Equal(100m, row.Exam.MaximumTargetNet); Assert.Equal(80m, row.TargetNet);
        var active = await client.GetFromJsonAsync<PreparationDto>("/api/user-exams/active"); Assert.Equal(row, active);
        await using var db = factory.CreateDatabase(); Assert.Equal(auth.User.Id, (await db.UserExams.SingleAsync()).UserId);
        var raw = await client.GetStringAsync("/api/user-exams/active");
        Assert.DoesNotContain("userId", raw); Assert.DoesNotContain("password", raw, StringComparison.OrdinalIgnoreCase);
    }
    [Fact]
    public async Task Ownership_and_exam_injection_are_rejected()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); await SignIn(client);
        var create = await client.PostAsJsonAsync("/api/user-exams", new { examId = Ales, targetNet = 80, examDate = Future, userId = Guid.NewGuid() });
        Assert.Equal(HttpStatusCode.BadRequest, create.StatusCode);
        var row = await Create(client);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PutAsJsonAsync($"/api/user-exams/{row.Id}", new { examId = Yks, targetNet = 81, examDate = Future })).StatusCode);
    }
    [Fact]
    public async Task Another_users_preparation_cannot_be_read_or_updated()
    {
        await using var factory = new AuthApiFactory(); using var a = factory.CreateClient(); using var b = factory.CreateClient();
        await SignIn(a); var row = await Create(a); await SignIn(b, "other@example.test");
        Assert.Equal(HttpStatusCode.NoContent, (await b.GetAsync("/api/user-exams/active")).StatusCode);
        Assert.Equal(HttpStatusCode.MethodNotAllowed, (await b.GetAsync($"/api/user-exams/{row.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await b.PutAsJsonAsync($"/api/user-exams/{row.Id}", new UpdatePreparationRequest(20, Future))).StatusCode);
        Assert.Equal(80, (await a.GetFromJsonAsync<PreparationDto>("/api/user-exams/active"))!.TargetNet);
    }
    [Theory]
    [InlineData(false)] [InlineData(true)]
    public async Task Missing_or_inactive_exam_is_not_found(bool inactive)
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); await SignIn(client);
        var id = Guid.NewGuid();
        if (inactive) { await using var db = factory.CreateDatabase(); var exam = await db.Exams.SingleAsync(x => x.Id == Ales); exam.Deactivate(); await db.SaveChangesAsync(); id = Ales; }
        Assert.Equal(HttpStatusCode.NotFound, (await client.PostAsJsonAsync("/api/user-exams", new CreatePreparationRequest(id, 80, Future))).StatusCode);
    }
    [Theory]
    [InlineData("0")] [InlineData("-1")] [InlineData("100.0001")] [InlineData("0.00001")] [InlineData("100000000")]
    public async Task Invalid_targets_are_rejected(string target)
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); await SignIn(client);
        var value = decimal.Parse(target, System.Globalization.CultureInfo.InvariantCulture);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/user-exams", new CreatePreparationRequest(Ales, value, Future))).StatusCode);
    }
    [Fact]
    public async Task Unknown_maximum_does_not_invent_a_limit()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); await SignIn(client);
        var row = await Create(client, Yks, 501.125m); Assert.Null(row.Exam.MaximumTargetNet);
        var exams = await client.GetFromJsonAsync<List<ExamDto>>("/api/exams");
        Assert.Null(exams!.Single(x => x.Id == Yks).MaximumTargetNet); Assert.Equal(100m, exams!.Single(x => x.Id == Ales).MaximumTargetNet);
    }
    [Fact]
    public async Task Incomplete_sections_never_claim_an_official_maximum()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient();
        await using var db = factory.CreateDatabase();
        var exam = await db.Exams.SingleAsync(x => x.Id == Yks); db.ExamSections.Add(new ExamSection(exam, "FIXTURE", "Test only", 3, 4));
        (await db.ExamSections.FirstAsync(x => x.ExamId == Ales)).Deactivate(); await db.SaveChangesAsync();
        var exams = await client.GetFromJsonAsync<List<ExamDto>>("/api/exams");
        Assert.Null(exams!.Single(x => x.Id == Yks).MaximumTargetNet); Assert.Null(exams!.Single(x => x.Id == Ales).MaximumTargetNet);
    }
    [Fact]
    public async Task Past_dates_and_missing_date_are_rejected()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); await SignIn(client);
        foreach (var date in new[] { DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-2)), default })
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/user-exams", new CreatePreparationRequest(Ales, 80, date))).StatusCode);
    }
    [Fact]
    public void Server_calendar_is_Turkey_and_date_only()
    {
        var today = PreparationRules.Today(new DateTimeOffset(2026, 9, 30, 22, 0, 0, TimeSpan.Zero));
        Assert.Equal(new DateOnly(2026, 10, 1), today);
        Assert.Empty(PreparationRules.Validate(80.25m, today, 100, today));
        Assert.Contains("examDate", PreparationRules.Validate(80, today.AddDays(-1), 100, today).Keys);
    }
    [Fact]
    public async Task Update_changes_goal_and_date_but_preserves_identity()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); await SignIn(client); var before = await Create(client);
        var response = await client.PutAsJsonAsync($"/api/user-exams/{before.Id}", new UpdatePreparationRequest(85.125m, Future.AddDays(1)));
        response.EnsureSuccessStatusCode(); var after = (await response.Content.ReadFromJsonAsync<PreparationDto>())!;
        Assert.Equal(before.Id, after.Id); Assert.Equal(before.Exam, after.Exam); Assert.Equal(before.CreatedAtUtc, after.CreatedAtUtc);
        Assert.Equal(85.125m, after.TargetNet); Assert.Equal(Future.AddDays(1), after.ExamDate); Assert.NotNull(after.UpdatedAtUtc);
    }
    [Fact]
    public async Task Replacement_preserves_history_and_identical_post_is_idempotent()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); await SignIn(client);
        var first = await Create(client); Assert.Equal(first.Id, (await Create(client)).Id);
        var next = await Create(client, Yks, 90);
        await using var db = factory.CreateDatabase(); Assert.Equal(2, await db.UserExams.CountAsync());
        Assert.Equal(next.Id, (await db.UserExams.SingleAsync(x => x.IsActive)).Id);
        Assert.False((await db.UserExams.SingleAsync(x => x.Id == first.Id)).IsActive);
        Assert.Equal(HttpStatusCode.Conflict, (await client.PutAsJsonAsync($"/api/user-exams/{first.Id}", new UpdatePreparationRequest(75, Future))).StatusCode);
    }
    [Fact]
    public async Task Invalid_replacement_does_not_deactivate_previous_preparation()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); await SignIn(client); var row = await Create(client);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/user-exams", new CreatePreparationRequest(Ales, 101, Future))).StatusCode);
        Assert.Equal(row.Id, (await client.GetFromJsonAsync<PreparationDto>("/api/user-exams/active"))!.Id);
    }
    [Fact]
    public async Task Database_partial_index_rejects_a_second_active_record()
    {
        await using var database = new TestDatabase(); await using var db = database.CreateContext();
        var user = new User("index@example.test", "Index"); var exam = await db.Exams.SingleAsync(x => x.Id == Ales);
        db.AddRange(user, new UserExam(user, exam, 80, Future)); await db.SaveChangesAsync();
        db.UserExams.Add(new UserExam(user, exam, 90, Future));
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }
    [Fact]
    public async Task Concurrent_creates_leave_exactly_one_active_preparation()
    {
        await using var factory = new AuthApiFactory(); using var client = factory.CreateClient(); await SignIn(client);
        var responses = await Task.WhenAll(Enumerable.Range(0, 3).Select(i => client.PostAsJsonAsync("/api/user-exams", new CreatePreparationRequest(Ales, 80 + i, Future))));
        Assert.All(responses, response => Assert.Contains(response.StatusCode, new[] { HttpStatusCode.Created, HttpStatusCode.Conflict }));
        await using var db = factory.CreateDatabase(); Assert.Equal(1, await db.UserExams.CountAsync(x => x.IsActive));
    }
}

