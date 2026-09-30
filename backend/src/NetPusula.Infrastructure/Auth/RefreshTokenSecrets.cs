using System.Security.Cryptography;
using System.Text;

namespace NetPusula.Infrastructure.Auth;

internal static class RefreshTokenSecrets
{
    // 256 bits of entropy; fixed-length hex transport avoids alternate encodings.
    internal static string Generate() => Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
    internal static bool IsValid(string? token) => token is { Length: 64 } && token.All(c => c is >= '0' and <= '9' or >= 'A' and <= 'F');
    internal static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.ASCII.GetBytes(token)));
}

