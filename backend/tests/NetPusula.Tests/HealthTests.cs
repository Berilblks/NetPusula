using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;

namespace NetPusula.Tests;

public sealed class HealthTests
{
    [Theory]
    [InlineData("Development")]
    [InlineData("Production")]
    public async Task Health_returns_only_healthy_status(string environment)
    {
        await using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder => builder.WithTestAuthentication().UseEnvironment(environment));
        using var client = factory.CreateClient(new() { BaseAddress = new Uri("https://localhost") });
        var response = await client.GetAsync("/api/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<Dictionary<string, string>>();
        Assert.NotNull(body);
        Assert.Single(body);
        Assert.Equal("healthy", body["status"]);
        var swagger = await client.GetAsync("/swagger/v1/swagger.json");
        Assert.Equal(environment == "Development" ? HttpStatusCode.OK : HttpStatusCode.NotFound, swagger.StatusCode);
    }

    [Theory]
    [InlineData("https://allowed.test", true)]
    [InlineData("https://blocked.test", false)]
    public async Task Cors_only_accepts_configured_origins(string origin, bool allowed)
    {
        await using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            builder.WithTestAuthentication().UseEnvironment("Production").ConfigureAppConfiguration((_, configuration) =>
                configuration.AddInMemoryCollection(new Dictionary<string, string?> { ["Cors:AllowedOrigins:0"] = "https://allowed.test" })));
        using var client = factory.CreateClient(new() { BaseAddress = new Uri("https://localhost") });
        using var request = new HttpRequestMessage(HttpMethod.Options, "/api/health");
        request.Headers.Add("Origin", origin);
        request.Headers.Add("Access-Control-Request-Method", "GET");
        var response = await client.SendAsync(request);
        Assert.Equal(allowed, response.Headers.Contains("Access-Control-Allow-Origin"));
    }
}


