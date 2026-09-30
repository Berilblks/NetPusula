using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using NetPusula.Application.Auth;
using NetPusula.Domain;

namespace NetPusula.Tests;

public sealed class AuthTests
{
    private const string Password = "Example password 42";
    private static async Task<AuthResponse> Register(HttpClient client, string email = "user@example.test")
    {
        var response = await client.PostAsJsonAsync("/api/auth/register",
            new { displayName = "  Test User  ", email, password = Password });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.True(response.Headers.CacheControl?.NoStore);
        return (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
    }

    [Fact]
    public async Task Registration_hashes_secrets_and_me_returns_only_safe_profile()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var auth = await Register(client, " User@Example.Test ");
        await using var db = factory.CreateDatabase();
        var user = await db.Users.SingleAsync();
        Assert.Equal("Test User", user.DisplayName);
        Assert.Equal("User@Example.Test", user.Email);
        Assert.Equal("USER@EXAMPLE.TEST", user.NormalizedEmail);
        Assert.NotEqual(Password, user.PasswordHash);
        var hasher = factory.Services.GetRequiredService<IPasswordHasher<User>>();
        Assert.Equal(PasswordVerificationResult.Success, hasher.VerifyHashedPassword(user, user.PasswordHash!, Password));
        var refresh = await db.RefreshTokens.SingleAsync();
        Assert.NotEqual(auth.RefreshToken, refresh.TokenHash);
        Assert.Equal(Convert.ToHexString(SHA256.HashData(Encoding.ASCII.GetBytes(auth.RefreshToken))), refresh.TokenHash);
        Assert.Equal(refresh.Id, refresh.FamilyId);
        Assert.Equal(30, (refresh.ExpiresAtUtc - refresh.CreatedAtUtc).TotalDays);
        var jwt = new JwtSecurityTokenHandler().ReadJwtToken(auth.AccessToken);
        Assert.Equal(user.Id.ToString(), jwt.Subject);
        Assert.DoesNotContain(jwt.Claims, c => c.Type == "email");
        Assert.Equal(15, (jwt.ValidTo - jwt.ValidFrom).TotalMinutes);

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/auth/me")).StatusCode);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var me = await client.GetAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.OK, me.StatusCode);
        using var json = JsonDocument.Parse(await me.Content.ReadAsStringAsync());
        Assert.Equal(new[] { "displayName", "email", "id" }, json.RootElement.EnumerateObject().Select(x => x.Name).Order().ToArray());
        Assert.Equal(user.Id, json.RootElement.GetProperty("id").GetGuid());

        using var anonymous = factory.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await anonymous.GetAsync("/api/health")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await anonymous.GetAsync("/api/exams")).StatusCode);
        var logs = string.Join("\n", factory.Logs);
        foreach (var secret in new[] { Password, auth.AccessToken, auth.RefreshToken, refresh.TokenHash, user.PasswordHash!, factory.Key })
            Assert.DoesNotContain(secret, logs);
    }

    [Theory]
    [InlineData("user@example.test")]
    [InlineData(" USER@EXAMPLE.TEST ")]
    public async Task Duplicate_email_is_conflict(string duplicate)
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        await Register(client);
        var response = await client.PostAsJsonAsync("/api/auth/register",
            new { displayName = "Other User", email = duplicate, password = Password });
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        await using var db = factory.CreateDatabase();
        Assert.Equal(1, await db.Users.CountAsync());
        Assert.Equal(1, await db.RefreshTokens.CountAsync());
    }

    [Theory]
    [InlineData("name", "not-email", "Password123")]
    [InlineData("name", "Name <user@example.test>", "Password123")]
    [InlineData("name", "", "Password123")]
    [InlineData(" ", "user@example.test", "Password123")]
    [InlineData("x", "user@example.test", "Password123")]
    [InlineData("name", "user@example.test", "short1")]
    [InlineData("name", "user@example.test", "onlyletters")]
    [InlineData("name", "user@example.test", "123456789")]
    [InlineData("name", "user@example.test", null)]
    public async Task Invalid_registration_is_validation_problem(string name, string email, string? password)
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/register", new { displayName = name, email, password });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType!.MediaType);
        await using var db = factory.CreateDatabase();
        Assert.Empty(await db.Users.ToListAsync());
    }

    [Fact]
    public async Task Overlong_credentials_are_bounded()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        foreach (var request in new[]
        {
            new RegisterRequest { DisplayName = new string('a', 121), Email = "u@example.test", Password = Password },
            new RegisterRequest { DisplayName = "User", Email = new string('a', 250) + "@example.test", Password = Password },
            new RegisterRequest { DisplayName = "User", Email = "u@example.test", Password = new string('a', 128) + "1" }
        })
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/auth/register", request)).StatusCode);
    }

    [Fact]
    public async Task Login_normalizes_email_and_hides_credential_failure_reason()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        await Register(client);
        var valid = await client.PostAsJsonAsync("/api/auth/login", new { email = " USER@EXAMPLE.TEST ", password = Password });
        Assert.Equal(HttpStatusCode.OK, valid.StatusCode);
        Assert.NotEmpty((await valid.Content.ReadFromJsonAsync<AuthResponse>())!.AccessToken);
        var wrong = await client.PostAsJsonAsync("/api/auth/login", new { email = "user@example.test", password = "Wrong password 7" });
        var unknown = await client.PostAsJsonAsync("/api/auth/login", new { email = "unknown@example.test", password = "Wrong password 7" });
        Assert.Equal(HttpStatusCode.Unauthorized, wrong.StatusCode);
        Assert.Equal(wrong.StatusCode, unknown.StatusCode);
        Assert.Equal(await wrong.Content.ReadAsStringAsync(), await unknown.Content.ReadAsStringAsync());
        Assert.DoesNotContain("Wrong password 7", string.Join("\n", factory.Logs));
    }

    [Theory]
    [InlineData("expired")]
    [InlineData("future")]
    [InlineData("issuer")]
    [InlineData("audience")]
    [InlineData("signature")]
    [InlineData("subject")]
    [InlineData("unsigned")]
    [InlineData("malformed")]
    public async Task Me_rejects_invalid_jwt(string fault)
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var auth = await Register(client);
        var now = DateTime.UtcNow;
        var key = fault == "signature" ? RandomNumberGenerator.GetBytes(32) : Convert.FromBase64String(factory.Key);
        var jwt = new JwtSecurityToken(
            fault == "issuer" ? "wrong" : "NetPusula.Tests",
            fault == "audience" ? "wrong" : "NetPusula.Tests.Client",
            [new Claim("sub", fault == "subject" ? "not-a-guid" : auth.User.Id.ToString())],
            fault == "expired" ? now.AddMinutes(-10) : fault == "future" ? now.AddMinutes(5) : now.AddSeconds(-1),
            fault == "expired" ? now.AddMinutes(-1) : now.AddMinutes(15),
            fault == "unsigned" ? null : new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256));
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer",
            fault == "malformed" ? "invalid.jwt.value" : new JwtSecurityTokenHandler().WriteToken(jwt));
        var response = await client.GetAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType!.MediaType);
        Assert.DoesNotContain("IDX", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Refresh_rotates_and_replay_revokes_only_its_own_family()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var auth = await Register(client);
        var login = await client.PostAsJsonAsync("/api/auth/login", new { email = auth.User.Email, password = Password });
        var otherSession = (await login.Content.ReadFromJsonAsync<AuthResponse>())!;
        var response = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var rotated = (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.NotEqual(auth.RefreshToken, rotated.RefreshToken);
        Assert.NotEqual(auth.AccessToken, rotated.AccessToken);
        await using (var db = factory.CreateDatabase())
        {
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.ASCII.GetBytes(auth.RefreshToken)));
            var old = await db.RefreshTokens.SingleAsync(x => x.TokenHash == hash);
            Assert.NotNull(old.RevokedAtUtc);
            Assert.NotNull(old.ReplacedByTokenId);
            Assert.Equal(old.FamilyId, (await db.RefreshTokens.SingleAsync(x => x.Id == old.ReplacedByTokenId)).FamilyId);
        }
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = rotated.RefreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = otherSession.RefreshToken })).StatusCode);
    }

    [Fact]
    public async Task Expired_refresh_is_rejected()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var auth = await Register(client);
        factory.Clock.Advance(TimeSpan.FromDays(30)); // Boundary is exclusive.
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken })).StatusCode);
        await using var db = factory.CreateDatabase();
        Assert.Equal(1, await db.RefreshTokens.CountAsync());
    }

    [Fact]
    public async Task Logout_is_idempotent_and_access_token_remains_valid()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var auth = await Register(client);
        for (var i = 0; i < 2; i++)
            Assert.Equal(HttpStatusCode.NoContent,
                (await client.PostAsJsonAsync("/api/auth/logout", new { refreshToken = auth.RefreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.PostAsJsonAsync("/api/auth/logout", new { refreshToken = "unknown" })).StatusCode);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/auth/me")).StatusCode);
        await using var db = factory.CreateDatabase();
        Assert.NotNull((await db.RefreshTokens.SingleAsync()).RevokedAtUtc);
    }

    [Fact]
    public async Task Logout_with_pre_rotation_token_revokes_replacement()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var auth = await Register(client);
        var response = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken });
        var rotated = (await response.Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.PostAsJsonAsync("/api/auth/logout", new { refreshToken = auth.RefreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = rotated.RefreshToken })).StatusCode);
    }

    [Fact]
    public async Task Concurrent_refresh_allows_only_one_success()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var auth = await Register(client);
        var responses = await Task.WhenAll(Enumerable.Range(0, 2).Select(_ => Task.Run(() =>
            client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth.RefreshToken }))));
        Assert.Single(responses, x => x.StatusCode == HttpStatusCode.OK);
        Assert.Single(responses, x => x.StatusCode == HttpStatusCode.Unauthorized);
        await using var db = factory.CreateDatabase();
        Assert.Equal(2, await db.RefreshTokens.CountAsync());
        Assert.All(await db.RefreshTokens.ToListAsync(), x => Assert.NotNull(x.RevokedAtUtc));
    }

    [Fact]
    public async Task Auth_rate_limit_does_not_trust_forwarded_headers_or_block_public_health()
    {
        await using var factory = new AuthApiFactory(1);
        using var client = factory.CreateClient();
        await client.PostAsJsonAsync("/api/auth/login", new { email = "u@example.test", password = Password });
        client.DefaultRequestHeaders.Add("X-Forwarded-For", "203.0.113.10");
        var response = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = "invalid" });
        Assert.Equal(HttpStatusCode.TooManyRequests, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType!.MediaType);
        Assert.NotNull(response.Headers.RetryAfter);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/health")).StatusCode);
    }
}

