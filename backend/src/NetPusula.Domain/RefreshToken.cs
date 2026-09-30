namespace NetPusula.Domain;

public sealed class RefreshToken
{
    private RefreshToken() { }

    public RefreshToken(Guid userId, string tokenHash, DateTime createdAtUtc, DateTime expiresAtUtc, Guid? familyId = null)
    {
        if (userId == Guid.Empty || createdAtUtc.Kind != DateTimeKind.Utc || expiresAtUtc.Kind != DateTimeKind.Utc
            || expiresAtUtc <= createdAtUtc)
            throw new ArgumentException("Invalid refresh token metadata.");
        if (tokenHash.Length != 64 || !tokenHash.All(Uri.IsHexDigit))
            throw new ArgumentException("Expected SHA-256 hexadecimal hash.", nameof(tokenHash));
        Id = Guid.NewGuid();
        UserId = userId;
        TokenHash = tokenHash;
        CreatedAtUtc = createdAtUtc;
        ExpiresAtUtc = expiresAtUtc;
        FamilyId = familyId ?? Id;
    }

    public Guid Id { get; private set; }
    public Guid UserId { get; private set; }
    public Guid FamilyId { get; private set; }
    public string TokenHash { get; private set; } = null!;
    public DateTime CreatedAtUtc { get; private set; }
    public DateTime ExpiresAtUtc { get; private set; }
    public DateTime? RevokedAtUtc { get; private set; }
    public Guid? ReplacedByTokenId { get; private set; }

    public void Revoke(DateTime now, Guid? replacementId = null)
    {
        if (now.Kind != DateTimeKind.Utc) throw new ArgumentException("Expected UTC.", nameof(now));
        if (RevokedAtUtc is not null) return;
        RevokedAtUtc = now;
        ReplacedByTokenId = replacementId;
    }
}

