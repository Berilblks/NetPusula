namespace NetPusula.Application.Auth;

public sealed class GoogleLinkRequest
{
    public string? IdToken { get; init; }
    public string? CurrentPassword { get; init; }
}
public sealed record GoogleLinkOutcome(UserProfile? User = null, string? Error = null);

public sealed class GoogleLoginRequest
{
    public string? IdToken { get; init; }
}

// Only produced after cryptographic validation. Never returned to the client.
public sealed record GoogleIdentity(string Subject, string Email, string DisplayName);
public sealed record GoogleValidation(GoogleIdentity? Identity, bool Unavailable = false);
public interface IGoogleTokenValidator
{
    Task<GoogleValidation> ValidateAsync(string token, CancellationToken cancellationToken);
}
