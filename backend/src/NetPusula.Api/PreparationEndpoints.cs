using NetPusula.Application.Auth;
using NetPusula.Application.Preparations;

namespace NetPusula.Api;

public static class PreparationEndpoints
{
    public static void MapPreparationEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/user-exams").RequireAuthorization().WithTags("User preparations");
        group.MapGet("/active", async (ICurrentUser current, IPreparationService service, CancellationToken ct) =>
        {
            if (current.UserId is not Guid userId) return Results.Unauthorized();
            var row = await service.ActiveAsync(userId, ct);
            return row is null ? Results.NoContent() : Results.Ok(row);
        });
        group.MapPost("/", async (CreatePreparationRequest request, ICurrentUser current, IPreparationService service, CancellationToken ct) =>
            current.UserId is Guid userId ? Map(await service.CreateAsync(userId, request, ct), true) : Results.Unauthorized());
        group.MapPut("/{id:guid}", async (Guid id, UpdatePreparationRequest request, ICurrentUser current, IPreparationService service, CancellationToken ct) =>
            current.UserId is Guid userId ? Map(await service.UpdateAsync(userId, id, request, ct), false) : Results.Unauthorized());
    }
    private static IResult Map(PreparationResult result, bool created) => result.Failure switch
    {
        PreparationFailure.Validation => Results.ValidationProblem(result.Errors!),
        PreparationFailure.NotFound => Results.Problem(statusCode: 404, title: "Preparation or active exam not found."),
        PreparationFailure.Conflict => Results.Problem(statusCode: 409, title: "Preparation changed. Reload and retry."),
        _ => created ? Results.Created("/api/user-exams/active", result.Value) : Results.Ok(result.Value)
    };
}
