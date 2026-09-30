using System.Net.Mail;

namespace NetPusula.Application.Auth;

public static class AuthValidation
{
    public static bool ValidEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email)) return false;
        email = email.Trim();
        // Deliberately bounded mailbox policy; no display-name syntax or Unicode mailbox ambiguity.
        return email.Length <= 254 && email.All(c => c > 32 && c < 127)
            && MailAddress.TryCreate(email, out var address)
            && address.Address.Equals(email, StringComparison.Ordinal)
            && !email.Contains('"');
    }

    public static Dictionary<string, string[]> Registration(RegisterRequest request)
    {
        var errors = new Dictionary<string, string[]>();
        var name = request.DisplayName?.Trim();
        if (name is null || name.Length is < 2 or > 120 || name.Any(char.IsControl))
            errors["displayName"] = ["Display name must contain 2 to 120 characters."];
        if (!ValidEmail(request.Email))
            errors["email"] = ["A valid email address is required (maximum 254 ASCII characters)."];
        var password = request.Password;
        if (password is null || password.Length is < 8 or > 128 || !password.Any(char.IsLetter)
            || !password.Any(char.IsDigit) || password.Any(char.IsControl))
            errors["password"] = ["Password must contain 8 to 128 characters, a letter and a number, with no control characters."];
        return errors;
    }
}

