using System.Security.Cryptography;
using Microsoft.AspNetCore.Identity;
using NetPusula.Domain;

namespace NetPusula.Infrastructure.Auth;

// One genuine work-factor hash per process: unknown accounts still perform password verification.
public sealed class PasswordTimingHash(IPasswordHasher<User> hasher)
{
    public User User { get; } = new("timing@example.invalid", "Timing");
    public string Hash { get; } = hasher.HashPassword(new User("timing@example.invalid", "Timing"),
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)));
}

