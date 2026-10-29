using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using NetPusula.Api;

namespace NetPusula.Tests;

public sealed class ReleaseHardeningTests
{
    [Theory]
    [InlineData("")]
    [InlineData("not a connection string")]
    public async Task Production_rejects_missing_or_malformed_database_configuration(string connection)
    {
        // Own startup/disposal: the minimal API entry point's Run disposes a failed
        // host before WebApplicationFactory can observe its startup exception.
        using var host = CreateValidationHost("Production", connection);
        var exception = await Assert.ThrowsAsync<OptionsValidationException>(() => host.StartAsync());
        Assert.Equal(typeof(DatabaseConnectionOptions), exception.OptionsType);
    }

    [Theory]
    [InlineData("Production", "Host=localhost;Database=configuration_only")]
    [InlineData("Development", "")]
    public async Task Database_validation_allows_valid_production_or_development_configuration(
        string environment, string connection)
    {
        using var host = CreateValidationHost(environment, connection);
        await host.StartAsync();
        await host.StopAsync();
    }

    private static IHost CreateValidationHost(string environment, string connection) =>
        new HostBuilder().UseEnvironment(environment)
            .ConfigureAppConfiguration((_, c) => c.AddInMemoryCollection(
                new Dictionary<string, string?> { ["ConnectionStrings:Database"] = connection }))
            .ConfigureServices((context, services) =>
                services.AddDatabaseConnectionValidation(context.HostingEnvironment))
            .Build();

    [Theory]
    [InlineData("/api/auth/register")]
    [InlineData("/api/auth/login")]
    [InlineData("/api/auth/refresh")]
    public async Task Auth_budget_is_shared_and_forwarded_header_does_not_bypass_it(string endpoint)
    {
        await using var factory = new AuthApiFactory(permitLimit: 2);
        using var client = factory.CreateClient();
        await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = "invalid" });
        await client.PostAsJsonAsync("/api/auth/login", new { email = "nobody@example.test", password = "invalid" });
        client.DefaultRequestHeaders.Add("X-Forwarded-For", "203.0.113.77");
        var response = await client.PostAsJsonAsync(endpoint, new { });
        Assert.Equal(HttpStatusCode.TooManyRequests, response.StatusCode);
        Assert.NotNull(response.Headers.RetryAfter);
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    [Theory]
    [InlineData("/api/auth/me")]
    [InlineData("/api/user-exams/active")]
    [InlineData("/api/mock-exams")]
    [InlineData("/api/dashboard")]
    [InlineData("/api/statistics")]
    public async Task Invalid_bearer_is_generic_uncacheable_problem(string path)
    {
        await using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new("Bearer", "malformed");
        var response = await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.DoesNotContain("malformed", await response.Content.ReadAsStringAsync());
    }
}
