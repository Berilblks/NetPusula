namespace NetPusula.Domain;

public sealed class User : Entity
{
    private User() { }
    public User(string email, string displayName)
    {
        Email = Guard.Text(email, 320);
        NormalizedEmail = NormalizeEmail(Email);
        DisplayName = Guard.Text(displayName, 120);
    }

    public string Email { get; private set; } = null!;
    public string NormalizedEmail { get; private set; } = null!;
    public string DisplayName { get; private set; } = null!;
    // Existing pre-authentication records may have no credentials.
    public string? PasswordHash { get; private set; }
    public static string NormalizeEmail(string email) => email.Trim().ToUpperInvariant();
    public void SetPasswordHash(string hash) => PasswordHash = Guard.Text(hash, 1024);
}


