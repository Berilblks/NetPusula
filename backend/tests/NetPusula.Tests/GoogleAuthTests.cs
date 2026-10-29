using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.IdentityModel.Tokens;
using NetPusula.Api.Auth;
using NetPusula.Application.Auth;

namespace NetPusula.Tests;

public sealed class GoogleAuthTests
{
    private const string Audience = "test-server.apps.googleusercontent.com";
    [Fact]
    public async Task Link_requires_session_and_fresh_password_and_preserves_identity()
    {
        using var key = RSA.Create(2048);
        await using var factory = new AuthApiFactory();
        await using var host = Host(factory, key);
        using var client = host.CreateClient();
        var token = Token(key, email: "different@example.test");
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/auth/google/link", new { idToken = token, currentPassword = "Test-password-123!" })).StatusCode);
        var registered = await client.PostAsJsonAsync("/api/auth/register", new { displayName = "Original Name", email = "local@example.test", password = "Test-password-123!" });
        var session = (await registered.Content.ReadFromJsonAsync<AuthResponse>())!;
        client.DefaultRequestHeaders.Authorization = new("Bearer", session.AccessToken);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/auth/google/link", new { idToken = token, currentPassword = "wrong" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/auth/google/link", new { idToken = "invalid", currentPassword = "Test-password-123!" })).StatusCode);
        for (var i = 0; i < 2; i++)
        {
            var response = await client.PostAsJsonAsync("/api/auth/google/link", new { idToken = token, currentPassword = "Test-password-123!", userId = Guid.NewGuid() });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var profile = (await response.Content.ReadFromJsonAsync<UserProfile>())!;
            Assert.Equal(session.User.Id, profile.Id);
            Assert.Equal("local@example.test", profile.Email);
            Assert.Equal("Original Name", profile.DisplayName);
            Assert.True(profile.GoogleLinked);
        }
        var googleLogin = (await (await client.PostAsJsonAsync("/api/auth/google", new { idToken = token })).Content.ReadFromJsonAsync<AuthResponse>())!;
        var passwordLogin = (await (await client.PostAsJsonAsync("/api/auth/login", new { email = "local@example.test", password = "Test-password-123!" })).Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.Equal(session.User.Id, googleLogin.User.Id);
        Assert.Equal(session.User.Id, passwordLogin.User.Id);
        await using var db = factory.CreateDatabase();
        Assert.Equal(1, await db.Users.CountAsync());
        Assert.NotNull((await db.Users.SingleAsync()).PasswordHash);
        Assert.DoesNotContain(token, string.Join("\n", factory.Logs));
        Assert.DoesNotContain("Test-password-123!", string.Join("\n", factory.Logs));
    }

    [Fact]
    public async Task Link_cannot_claim_another_users_subject_or_replace_own_subject()
    {
        using var key = RSA.Create(2048);
        await using var factory = new AuthApiFactory();
        await using var host = Host(factory, key);
        using var client = host.CreateClient();
        var owned = Token(key, sub: "already-owned");
        await client.PostAsJsonAsync("/api/auth/google", new { idToken = owned });
        var local = (await (await client.PostAsJsonAsync("/api/auth/register", new { displayName = "Local", email = "local@example.test", password = "Test-password-123!" })).Content.ReadFromJsonAsync<AuthResponse>())!;
        client.DefaultRequestHeaders.Authorization = new("Bearer", local.AccessToken);
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsJsonAsync("/api/auth/google/link", new { idToken = owned, currentPassword = "Test-password-123!" })).StatusCode);
        var mine = Token(key, sub: "mine", email: "local@example.test");
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/auth/google/link", new { idToken = mine, currentPassword = "Test-password-123!" })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsJsonAsync("/api/auth/google/link", new { idToken = Token(key, sub: "replacement"), currentPassword = "Test-password-123!" })).StatusCode);
        await using var db = factory.CreateDatabase();
        Assert.Equal("mine", (await db.Users.SingleAsync(x => x.Id == local.User.Id)).GoogleSubject);
        Assert.Equal(2, await db.Users.CountAsync());
    }

    [Theory]
    [InlineData("signature")]
    [InlineData("audience")]
    [InlineData("expired")]
    [InlineData("issuer")]
    public async Task Link_rejects_unverified_tokens_without_mutation(string kind)
    {
        using var key = RSA.Create(2048);
        using var other = RSA.Create(2048);
        await using var factory = new AuthApiFactory();
        await using var host = Host(factory, key);
        using var client = host.CreateClient();
        var local = (await (await client.PostAsJsonAsync("/api/auth/register", new { displayName = "Local", email = "local@example.test", password = "Test-password-123!" })).Content.ReadFromJsonAsync<AuthResponse>())!;
        client.DefaultRequestHeaders.Authorization = new("Bearer", local.AccessToken);
        var token = Token(kind == "signature" ? other : key, audience: kind == "audience" ? "wrong" : Audience, expired: kind == "expired", issuer: kind == "issuer" ? "wrong" : "https://accounts.google.com");
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/auth/google/link", new { idToken = token, currentPassword = "Test-password-123!" })).StatusCode);
        await using var db = factory.CreateDatabase();
        Assert.Null((await db.Users.SingleAsync()).GoogleSubject);
    }
    private sealed class TestKeys(SecurityKey key) : IGoogleSigningKeys
    {
        public Task<ICollection<SecurityKey>> GetAsync(bool refresh, CancellationToken cancellationToken) =>
            Task.FromResult<ICollection<SecurityKey>>([key]);
    }
    private static WebApplicationFactory<Program> Host(AuthApiFactory factory, RSA key) => factory.WithWebHostBuilder(builder =>
        builder.ConfigureServices(services =>
        {
            services.PostConfigure<GoogleAuthOptions>(o => { o.Enabled = true; o.Audiences = [Audience]; });
            services.RemoveAll<IGoogleSigningKeys>();
            services.AddSingleton<IGoogleSigningKeys>(new TestKeys(new RsaSecurityKey(key) { KeyId = "test-key" }));
        }));

    private static string Token(RSA key, string sub = "google-sub-1", string email = "google@example.test",
        string audience = Audience, string issuer = "https://accounts.google.com", bool verified = true,
        bool expired = false, bool future = false, bool noExpiry = false, string? name = "Google User")
    {
        var now = DateTime.UtcNow;
        var claims = new List<Claim> { new("sub", sub), new("email", email), new("email_verified", verified ? "true" : "false", ClaimValueTypes.Boolean) };
        if (name is not null) claims.Add(new("name", name));
        var jwt = new JwtSecurityToken(issuer, audience, claims,
            future ? now.AddHours(1) : now.AddHours(-2),
            noExpiry ? null : expired ? now.AddHours(-1) : now.AddHours(2),
            new SigningCredentials(new RsaSecurityKey(key) { KeyId = "test-key" }, SecurityAlgorithms.RsaSha256));
        return new JwtSecurityTokenHandler().WriteToken(jwt);
    }

    [Fact]
    public async Task Verified_google_identity_creates_passwordless_user_and_own_safe_session()
    {
        using var key = RSA.Create(2048);
        await using var factory = new AuthApiFactory();
        await using var host = Host(factory, key);
        using var client = host.CreateClient();
        var token = Token(key);
        var result = await client.PostAsJsonAsync("/api/auth/google", new { idToken = token });
        Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        Assert.True(result.Headers.CacheControl?.NoStore);
        var auth = (await result.Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.NotEqual(token, auth.AccessToken);
        await using var db = factory.CreateDatabase();
        var user = await db.Users.SingleAsync();
        Assert.Null(user.PasswordHash);
        Assert.Equal("google-sub-1", user.GoogleSubject);
        Assert.Equal("GOOGLE@EXAMPLE.TEST", user.NormalizedEmail);
        Assert.Equal(user.Id, auth.User.Id);
        Assert.Equal(1, await db.RefreshTokens.CountAsync());
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var me = await client.GetStringAsync("/api/auth/me");
        Assert.DoesNotContain("googleSubject", me);
        Assert.DoesNotContain("password", me, StringComparison.OrdinalIgnoreCase);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/auth/me")).StatusCode);
        var logs = string.Join("\n", factory.Logs);
        Assert.DoesNotContain(token, logs);
        Assert.DoesNotContain(auth.AccessToken, logs);
        Assert.DoesNotContain(auth.RefreshToken, logs);
    }

    [Theory]
    [InlineData("signature")]
    [InlineData("audience")]
    [InlineData("issuer")]
    [InlineData("expired")]
    [InlineData("future")]
    [InlineData("noExpiry")]
    [InlineData("unverified")]
    [InlineData("emptySubject")]
    [InlineData("invalidEmail")]
    [InlineData("malformed")]
    [InlineData("oversized")]
    [InlineData("empty")]
    public async Task Invalid_google_tokens_never_create_user_or_session(string kind)
    {
        using var key = RSA.Create(2048);
        using var attacker = RSA.Create(2048);
        await using var factory = new AuthApiFactory();
        await using var host = Host(factory, key);
        using var client = host.CreateClient();
        var token = kind switch
        {
            "malformed" => "not-a-token", "oversized" => new string('x', 8193), "empty" => "",
            _ => Token(kind == "signature" ? attacker : key,
                sub: kind == "emptySubject" ? "" : "subject",
                email: kind == "invalidEmail" ? "invalid" : "google@example.test",
                audience: kind == "audience" ? "another-app" : Audience,
                issuer: kind == "issuer" ? "https://attacker.example" : "https://accounts.google.com",
                verified: kind != "unverified", expired: kind == "expired", future: kind == "future", noExpiry: kind == "noExpiry")
        };
        var response = await client.PostAsJsonAsync("/api/auth/google", new { idToken = token });
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.DoesNotContain(token.Length > 0 ? token : "internal exception", await response.Content.ReadAsStringAsync());
        await using var db = factory.CreateDatabase();
        Assert.Empty(await db.Users.ToListAsync());
        Assert.Empty(await db.RefreshTokens.ToListAsync());
    }

    [Fact]
    public async Task Existing_password_account_is_not_linked_by_normalized_email()
    {
        using var key = RSA.Create(2048);
        await using var factory = new AuthApiFactory();
        await using var host = Host(factory, key);
        using var client = host.CreateClient();
        await client.PostAsJsonAsync("/api/auth/register", new { email = "Google@Example.Test", displayName = "Existing", password = "Example password 42" });
        var response = await client.PostAsJsonAsync("/api/auth/google", new { idToken = Token(key) });
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Contains("google_conflict", await response.Content.ReadAsStringAsync());
        await using var db = factory.CreateDatabase();
        Assert.Null((await db.Users.SingleAsync()).GoogleSubject);
        Assert.Equal(1, await db.RefreshTokens.CountAsync());
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/auth/login", new { email = "Google@Example.Test", password = "Example password 42" })).StatusCode);
    }

    [Fact]
    public async Task Repeated_google_login_uses_subject_not_mutable_email_and_rotates_refresh()
    {
        using var key = RSA.Create(2048);
        await using var factory = new AuthApiFactory();
        await using var host = Host(factory, key);
        using var client = host.CreateClient();
        var first = (await (await client.PostAsJsonAsync("/api/auth/google", new { idToken = Token(key) })).Content.ReadFromJsonAsync<AuthResponse>())!;
        var second = (await (await client.PostAsJsonAsync("/api/auth/google", new { idToken = Token(key, email: "changed@example.test") })).Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.Equal(first.User.Id, second.User.Id);
        Assert.NotEqual(first.RefreshToken, second.RefreshToken);
        var conflict = await client.PostAsJsonAsync("/api/auth/google", new { idToken = Token(key, sub: "different-sub") });
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/auth/login", new { email = first.User.Email, password = "anything" })).StatusCode);
        var refresh = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = second.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, refresh.StatusCode);
        var rotated = (await refresh.Content.ReadFromJsonAsync<AuthResponse>())!;
        Assert.NotEqual(second.RefreshToken, rotated.RefreshToken);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = second.RefreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = rotated.RefreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await client.PostAsJsonAsync("/api/auth/logout", new { refreshToken = first.RefreshToken })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = first.RefreshToken })).StatusCode);
        await using var db = factory.CreateDatabase();
        Assert.Single(await db.Users.ToListAsync());
    }

    [Fact]
    public async Task Missing_google_configuration_fails_closed_without_network()
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.PostAsJsonAsync("/api/auth/google", new { idToken = "test-only" })).StatusCode);
    }
}
