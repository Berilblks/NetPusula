using NetPusula.Application.Auth;

namespace NetPusula.Api.Auth;

public static class AuthEndpoints
{
    public static void MapAuthEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/auth").WithTags("Authentication");
        group.MapPost("/google/link", async (GoogleLinkRequest request, ICurrentUser current, IAuthService auth, CancellationToken ct) =>
        {
            if (current.UserId is not { } id) return Results.Unauthorized();
            var result = await auth.LinkGoogleAsync(id, request, ct);
            return result.Error is null ? Results.Ok(result.User) : Results.Problem(
                statusCode: result.Error switch { "session_expired" => 401, "google_link_conflict" => 409, "google_unavailable" => 503, _ => 400 },
                title: "Google account could not be linked.", extensions: new Dictionary<string, object?> { ["code"] = result.Error });
        }).RequireAuthorization().RequireRateLimiting("auth");
        group.MapPost("/google", async (GoogleLoginRequest request, IAuthService auth, CancellationToken ct) =>
            Map(await auth.GoogleAsync(request, ct))).RequireRateLimiting("auth").AllowAnonymous();
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
        AuthFailure.GoogleRejected => Results.Problem(statusCode: 401, title: "Google authentication could not be verified.", extensions: new Dictionary<string, object?> { ["code"] = "google_rejected" }),
        AuthFailure.GoogleConflict => Results.Problem(statusCode: 409, title: "Use the existing account sign-in method. Automatic linking is not supported.", extensions: new Dictionary<string, object?> { ["code"] = "google_conflict" }),
        AuthFailure.GoogleUnavailable => Results.Problem(statusCode: 503, title: "Google authentication is temporarily unavailable.", extensions: new Dictionary<string, object?> { ["code"] = "google_unavailable" }),
        _ => registration ? Results.Json(result.Response, statusCode: 201) : Results.Ok(result.Response)
    };
}

