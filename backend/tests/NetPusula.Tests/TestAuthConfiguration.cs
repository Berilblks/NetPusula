using System.Security.Cryptography;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace NetPusula.Tests;

internal static class TestAuthConfiguration
{
    internal static IWebHostBuilder WithTestAuthentication(this IWebHostBuilder builder) =>
        builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["ConnectionStrings:Database"] = "Host=localhost;Database=test_configuration_only",
                ["Jwt:Issuer"] = "NetPusula.Tests",
                ["Jwt:Audience"] = "NetPusula.Tests.Client",
                ["Jwt:SigningKey"] = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
            }));
}

