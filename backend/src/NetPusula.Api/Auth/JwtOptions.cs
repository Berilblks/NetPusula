namespace NetPusula.Api.Auth;

public sealed class JwtOptions
{
    public string Issuer { get; set; } = "";
    public string Audience { get; set; } = "";
    // Base64-encoded random bytes; never a memorable password or checked-in secret.
    public string SigningKey { get; set; } = "";
    public int AccessTokenMinutes { get; set; } = 15;

    public bool IsValid()
    {
        if (string.IsNullOrWhiteSpace(SigningKey) || string.IsNullOrWhiteSpace(Issuer) || string.IsNullOrWhiteSpace(Audience)
            || Issuer.Length > 200 || Audience.Length > 200 || AccessTokenMinutes is < 1 or > 60)
            return false;
        try { return Convert.FromBase64String(SigningKey).Length is >= 32 and <= 128; }
        catch (FormatException) { return false; }
    }
}

public sealed class AuthRateLimitOptions
{
    public int PermitLimit { get; set; } = 20;
    public int WindowSeconds { get; set; } = 60;
}


