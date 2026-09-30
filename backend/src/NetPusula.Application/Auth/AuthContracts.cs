namespace NetPusula.Application.Auth;

public sealed class RegisterRequest
{
    public string? DisplayName { get; init; }
    public string? Email { get; init; }
    public string? Password { get; init; }
}

public sealed class LoginRequest
{
    public string? Email { get; init; }
    public string? Password { get; init; }
}

public sealed class RefreshRequest
{
    public string? RefreshToken { get; init; }
}

public sealed record UserProfile(Guid Id, string DisplayName, string Email);
public sealed record AccessToken(string Value, DateTime ExpiresAtUtc);

public sealed class AuthResponse
{
    public required string AccessToken { get; init; }
    public required DateTime AccessTokenExpiresAtUtc { get; init; }
    public required string RefreshToken { get; init; }
    public required DateTime RefreshTokenExpiresAtUtc { get; init; }
    public required UserProfile User { get; init; }
    public string TokenType => "Bearer";
}

public enum AuthFailure { None, InvalidInput, InvalidCredentials, DuplicateEmail }

public sealed class AuthOutcome
{
    public AuthResponse? Response { get; init; }
    public AuthFailure Failure { get; init; }
    public Dictionary<string, string[]> Errors { get; init; } = [];
}

public interface IAuthService
{
    Task<AuthOutcome> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken);
    Task<AuthOutcome> LoginAsync(LoginRequest request, CancellationToken cancellationToken);
    Task<AuthOutcome> RefreshAsync(string? token, CancellationToken cancellationToken);
    Task LogoutAsync(string? token, CancellationToken cancellationToken);
    Task<UserProfile?> GetUserAsync(Guid userId, CancellationToken cancellationToken);
}

public interface IAccessTokenIssuer
{
    AccessToken Issue(Guid userId);
}

public interface ICurrentUser
{
    Guid? UserId { get; }
}

public sealed class AuthSessionOptions
{
    public int RefreshTokenDays { get; set; } = 30;
}

