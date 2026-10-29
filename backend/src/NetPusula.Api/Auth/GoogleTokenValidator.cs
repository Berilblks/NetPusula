using System.IdentityModel.Tokens.Jwt;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using NetPusula.Application.Auth;

namespace NetPusula.Api.Auth;

public sealed class GoogleAuthOptions
{
    public bool Enabled { get; set; }
    public string[] Audiences { get; set; } = [];
    public bool IsValid() => !Enabled || (Audiences.Length is > 0 and <= 10 &&
        Audiences.All(x => !string.IsNullOrWhiteSpace(x) && x.EndsWith(".apps.googleusercontent.com", StringComparison.Ordinal)
            && x.Length <= 256 && !x.Any(char.IsWhiteSpace)));
}

public interface IGoogleSigningKeys
{
    Task<ICollection<SecurityKey>> GetAsync(bool refresh, CancellationToken cancellationToken);
}

public sealed class GoogleSigningKeys : IGoogleSigningKeys
{
    // Fixed HTTPS authority, not taken from the untrusted token's jku/x5u/iss.
    private readonly ConfigurationManager<OpenIdConnectConfiguration> configuration = new(
        "https://accounts.google.com/.well-known/openid-configuration",
        new OpenIdConnectConfigurationRetriever(), new HttpDocumentRetriever { RequireHttps = true });

    public async Task<ICollection<SecurityKey>> GetAsync(bool refresh, CancellationToken cancellationToken)
    {
        if (refresh) configuration.RequestRefresh();
        return (await configuration.GetConfigurationAsync(cancellationToken)).SigningKeys;
    }
}

public sealed class GoogleTokenValidator(IOptions<GoogleAuthOptions> options, IGoogleSigningKeys keys,
    TimeProvider clock) : IGoogleTokenValidator
{
    public async Task<GoogleValidation> ValidateAsync(string token, CancellationToken cancellationToken)
    {
        var settings = options.Value;
        if (!settings.Enabled || !settings.IsValid()) return new(null, Unavailable: true);
        if (token.Length is < 1 or > 8192) return new(null);
        try
        {
            var handler = new JwtSecurityTokenHandler { MapInboundClaims = false, MaximumTokenSizeInBytes = 8192 };
            var parameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuers = ["accounts.google.com", "https://accounts.google.com"],
                ValidateAudience = true,
                ValidAudiences = settings.Audiences,
                ValidateIssuerSigningKey = true,
                RequireSignedTokens = true,
                ValidAlgorithms = [SecurityAlgorithms.RsaSha256],
                ValidateLifetime = true,
                RequireExpirationTime = true,
                ClockSkew = TimeSpan.Zero,
                LifetimeValidator = (notBefore, expires, _, _) => expires.HasValue &&
                    expires.Value > clock.GetUtcNow().UtcDateTime &&
                    (!notBefore.HasValue || notBefore.Value <= clock.GetUtcNow().UtcDateTime),
                IssuerSigningKeys = await keys.GetAsync(false, cancellationToken)
            };
            System.Security.Claims.ClaimsPrincipal principal;
            try { principal = handler.ValidateToken(token, parameters, out _); }
            catch (SecurityTokenSignatureKeyNotFoundException)
            {
                parameters.IssuerSigningKeys = await keys.GetAsync(true, cancellationToken);
                principal = handler.ValidateToken(token, parameters, out _);
            }
            var sub = principal.FindFirst("sub")?.Value;
            var email = principal.FindFirst("email")?.Value;
            var verified = principal.FindFirst("email_verified")?.Value;
            if (string.IsNullOrWhiteSpace(sub) || sub.Length > 255 || sub.Any(char.IsControl) ||
                !string.Equals(verified, "true", StringComparison.OrdinalIgnoreCase) || !AuthValidation.ValidEmail(email))
                return new(null);
            var name = principal.FindFirst("name")?.Value?.Trim();
            // Missing/oversized provider names must not prevent safe account creation.
            if (string.IsNullOrWhiteSpace(name) || name.Length > 120 || name.Any(char.IsControl)) name = "NetPusula Kullanıcısı";
            return new(new GoogleIdentity(sub, email!.Trim(), name));
        }
        catch (SecurityTokenException) { return new(null); }
        catch (ArgumentException) { return new(null); }
        catch (HttpRequestException) { return new(null, Unavailable: true); }
        catch (IOException) { return new(null, Unavailable: true); }
        catch (InvalidOperationException) { return new(null, Unavailable: true); }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested) { return new(null, Unavailable: true); }
        // Never log token/claims or exception contents.
    }
}
