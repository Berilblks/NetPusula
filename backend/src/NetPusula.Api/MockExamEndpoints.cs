using NetPusula.Application.Auth;
using NetPusula.Application.MockExams;
namespace NetPusula.Api;
public static class MockExamEndpoints
{
    public static void MapMockExamEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/mock-exams").RequireAuthorization().WithTags("Mock exams");
        group.MapGet("/", async (int? page, int? pageSize, ICurrentUser current, IMockExamService service, CancellationToken ct) =>
            current.UserId is Guid user ? Map(await service.ListAsync(user, page ?? 1, pageSize ?? 20, ct)) : Results.Unauthorized());
        group.MapGet("/{id:guid}", async (Guid id, ICurrentUser current, IMockExamService service, CancellationToken ct) =>
            current.UserId is Guid user ? Map(await service.DetailAsync(user, id, ct)) : Results.Unauthorized());
        group.MapPost("/", async (SaveMockExamRequest request, ICurrentUser current, IMockExamService service, CancellationToken ct) =>
        {
            if (current.UserId is not Guid user) return Results.Unauthorized();
            var result = await service.SaveAsync(user, null, request, ct);
            return result.Failure == MockFailure.None ? Results.Created($"/api/mock-exams/{result.Value!.Id}", result.Value) : Map(result);
        });
        group.MapPut("/{id:guid}", async (Guid id, SaveMockExamRequest request, ICurrentUser current, IMockExamService service, CancellationToken ct) =>
            current.UserId is Guid user ? Map(await service.SaveAsync(user, id, request, ct)) : Results.Unauthorized());
        group.MapDelete("/{id:guid}", async (Guid id, ICurrentUser current, IMockExamService service, CancellationToken ct) =>
        {
            if (current.UserId is not Guid user) return Results.Unauthorized();
            var result = await service.DeleteAsync(user, id, ct);
            return result.Failure == MockFailure.None ? Results.NoContent() : Map(result);
        });
    }
    private static IResult Map<T>(MockOutcome<T> result) => result.Failure switch
    {
        MockFailure.Validation => Results.Problem(statusCode: 400, title: "Invalid mock exam data."),
        MockFailure.NotFound => Results.Problem(statusCode: 404, title: "Mock exam not found."),
        MockFailure.NoPreparation => Results.Problem(statusCode: 409, title: "Active preparation required.", extensions: new Dictionary<string, object?> { ["code"] = "active_preparation_required" }),
        MockFailure.Conflict => Results.Problem(statusCode: 409, title: "Exam configuration is unavailable. Reload and retry."),
        _ => Results.Ok(result.Value)
    };
}
