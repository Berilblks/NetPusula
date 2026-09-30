using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using NetPusula.Domain;

namespace NetPusula.Tests;

public sealed class AuthSecurityTests
{
    [Fact]
    public void Application_rejects_missing_signing_key_at_startup()
    {
        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            builder.WithTestAuthentication().ConfigureAppConfiguration((_, configuration) =>
                configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["Jwt:SigningKey"] = "" })));
        Assert.Throws<OptionsValidationException>(() => factory.CreateClient());
    }

    [Theory]
    [InlineData("{")]
    [InlineData("null")]
    [InlineData("{\"password\": 123}")]
    public async Task Malformed_json_is_generic_problem(string body)
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var response = await client.PostAsync("/api/auth/register", new StringContent(body, Encoding.UTF8, "application/json"));
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType!.MediaType);
        Assert.DoesNotContain("Exception", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Production_auth_requires_https()
    {
        await using var factory = new AuthApiFactory();
        await using var production = factory.WithWebHostBuilder(builder => builder.UseEnvironment("Production"));
        using var client = production.CreateClient(new() { AllowAutoRedirect = false, BaseAddress = new Uri("http://localhost") });
        var response = await client.PostAsJsonAsync("/api/auth/login", new { email = "u@example.test", password = "Pass1234" });
        // No HTTPS port is configured in this isolated host; explicit auth guard rejects HTTP.
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("HTTPS", await response.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/health")).StatusCode);
    }

    [Fact]
    public async Task Legacy_hash_is_upgraded_and_null_hash_cannot_login()
    {
        await using var factory = new AuthApiFactory();
        string originalHash;
        await using (var db = factory.CreateDatabase())
        {
            var legacy = new User("legacy@example.test", "Legacy");
            var oldHasher = new PasswordHasher<User>(Options.Create(new PasswordHasherOptions { IterationCount = 10_000 }));
            originalHash = oldHasher.HashPassword(legacy, "Password123");
            legacy.SetPasswordHash(originalHash);
            db.Users.AddRange(legacy, new User("nohash@example.test", "No credentials"));
            await db.SaveChangesAsync();
        }
        using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/auth/login",
            new { email = "legacy@example.test", password = "Password123" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/auth/login",
            new { email = "nohash@example.test", password = "Password123" })).StatusCode);
        await using var check = factory.CreateDatabase();
        Assert.NotEqual(originalHash, (await check.Users.SingleAsync(x => x.Email == "legacy@example.test")).PasswordHash);
    }

    [Fact]
    public async Task Concurrent_registration_leaves_one_user_and_session()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var responses = await Task.WhenAll(Enumerable.Range(0, 2).Select(_ => Task.Run(() => client.PostAsJsonAsync(
            "/api/auth/register", new { displayName = "Concurrent", email = "same@example.test", password = "Password123" }))));
        Assert.Single(responses, x => x.StatusCode == HttpStatusCode.Created);
        Assert.Single(responses, x => x.StatusCode == HttpStatusCode.Conflict);
        await using var db = factory.CreateDatabase();
        Assert.Equal(1, await db.Users.CountAsync());
        Assert.Equal(1, await db.RefreshTokens.CountAsync());
    }

    [Fact]
    public async Task Persistence_rejects_duplicate_hash_and_stale_revocation_and_restricts_user_deletion()
    {
        await using var factory = new AuthApiFactory();
        await using var db = factory.CreateDatabase();
        var user = new User("token@example.test", "Token User");
        var now = DateTime.UtcNow;
        var token = new RefreshToken(user.Id, Convert.ToHexString(RandomNumberGenerator.GetBytes(32)), now, now.AddDays(30));
        db.AddRange(user, token);
        await db.SaveChangesAsync();
        db.RefreshTokens.Add(new RefreshToken(user.Id, token.TokenHash, now, now.AddDays(30)));
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        db.ChangeTracker.Clear();
        await using var concurrent = factory.CreateDatabase();
        var first = await db.RefreshTokens.SingleAsync();
        var second = await concurrent.RefreshTokens.SingleAsync();
        first.Revoke(now.AddSeconds(1));
        await db.SaveChangesAsync();
        second.Revoke(now.AddSeconds(2));
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => concurrent.SaveChangesAsync());
        await Assert.ThrowsAsync<Microsoft.Data.Sqlite.SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"DELETE FROM \"Users\" WHERE \"Id\" = {user.Id}"));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("invalid")]
    [InlineData("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")]
    public async Task Unknown_refresh_is_rejected_without_token_details(string? refreshToken)
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Contains("Invalid authentication credentials.", await response.Content.ReadAsStringAsync());
    }
}

