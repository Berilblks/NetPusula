using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using NetPusula.Application.Exams;
using NetPusula.Domain;
using NetPusula.Infrastructure;

namespace NetPusula.Tests;

public sealed class ExamApiTests
{
    private static WebApplicationFactory<Program> Factory(TestDatabase database) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            builder.WithTestAuthentication().UseEnvironment("Development").ConfigureServices(services =>
            {
                services.RemoveAll<NetPusulaDbContext>();
                services.AddScoped(_ => database.CreateContext());
            }));

    [Fact]
    public async Task Catalogue_endpoints_return_only_active_dtos_and_ordered_sections()
    {
        await using var database = new TestDatabase();
        Guid hiddenId;
        Guid alesId;
        await using (var db = database.CreateContext())
        {
            var hidden = new Exam("HIDDEN", "Hidden");
            hidden.Deactivate();
            hiddenId = hidden.Id;
            db.Exams.Add(hidden);
            var ales = await db.Exams.SingleAsync(x => x.Code == "ALES");
            alesId = ales.Id;
            var section = new ExamSection(ales, "HIDDEN", "Hidden", 1, 4);
            section.Deactivate();
            db.ExamSections.Add(section);
            await db.SaveChangesAsync();
        }
        await using var factory = Factory(database);
        using var client = factory.CreateClient();
        var exams = await client.GetFromJsonAsync<List<ExamDto>>("/api/exams");
        Assert.NotNull(exams);
        Assert.Equal(6, exams.Count);
        Assert.DoesNotContain(exams, x => x.Id == hiddenId);
        Assert.Equal(exams.OrderBy(x => x.SortOrder).ThenBy(x => x.Code).ToList(), exams);
        var exam = await client.GetFromJsonAsync<ExamDto>($"/api/exams/{alesId}");
        Assert.Equal("ALES", exam!.Code);
        var sections = await client.GetFromJsonAsync<List<ExamSectionDto>>($"/api/exams/{alesId}/sections");
        Assert.NotNull(sections);
        Assert.Equal(new[] { "SAYISAL", "SOZEL" }, sections.Select(x => x.Code));
        Assert.All(sections, x => { Assert.Equal(50, x.QuestionCount); Assert.Equal(4m, x.PenaltyDivisor); });
        var raw = await client.GetStringAsync("/api/exams");
        Assert.DoesNotContain("passwordHash", raw, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("createdAtUtc", raw, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/health")).StatusCode);
        foreach (var id in new[] { hiddenId, Guid.NewGuid() })
        {
            Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/exams/{id}")).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/exams/{id}/sections")).StatusCode);
        }
        var yks = exams.Single(x => x.Code == "YKS");
        Assert.Empty((await client.GetFromJsonAsync<List<ExamSectionDto>>($"/api/exams/{yks.Id}/sections"))!);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/api/exams/not-a-guid")).StatusCode);
        Assert.Equal(HttpStatusCode.MethodNotAllowed, (await client.PostAsJsonAsync("/api/exams", new { })).StatusCode);
    }
}


