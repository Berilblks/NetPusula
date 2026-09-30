using NetPusula.Application.Auth;

namespace NetPusula.Api.Auth;

public static class AuthEndpoints
{
    public static void MapAuthEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/auth").WithTags("Authentication");
        group.MapPost("/register", async (RegisterRequest request, IAuthService auth, CancellationToken ct) =>
            Map(await auth.RegisterAsync(request, ct), registration: true)).RequireRateLimiting("auth").AllowAnonymous();
        group.MapPost("/login", async (LoginRequest request, IAuthService auth, CancellationToken ct) =>
            Map(await auth.LoginAsync(request, ct))).RequireRateLimiting("auth").AllowAnonymous();
        group.MapPost("/refresh", async (RefreshRequest request, IAuthService auth, CancellationToken ct) =>
            Map(await auth.RefreshAsync(request.RefreshToken, ct))).RequireRateLimiting("auth").AllowAnonymous();
        group.MapPost("/logout", async (RefreshRequest request, IAuthService auth, CancellationToken ct) =>
        {
            // Possession of the refresh secret authorizes revocation, even if the access JWT expired.
            // Unknown/expired/already revoked tokens get the same idempotent response.
            await auth.LogoutAsync(request.RefreshToken, ct);
            return Results.NoContent();
        }).RequireRateLimiting("auth").AllowAnonymous();
        group.MapGet("/me", async (ICurrentUser current, IAuthService auth, CancellationToken ct) =>
        {
            var user = current.UserId is { } id ? await auth.GetUserAsync(id, ct) : null;
            return user is null ? Results.Problem(statusCode: 401, title: "Authentication required.") : Results.Ok(user);
        }).RequireAuthorization();
    }

    private static IResult Map(AuthOutcome result, bool registration = false) => result.Failure switch
    {
        AuthFailure.InvalidInput => Results.ValidationProblem(result.Errors),
        AuthFailure.InvalidCredentials => Results.Problem(statusCode: 401, title: "Invalid authentication credentials."),
        AuthFailure.DuplicateEmail => Results.Problem(statusCode: 409, title: "An account with this email already exists."),
        _ => registration ? Results.Json(result.Response, statusCode: 201) : Results.Ok(result.Response)
    };
}

