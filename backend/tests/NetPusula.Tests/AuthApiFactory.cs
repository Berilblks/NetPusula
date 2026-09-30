using System.Collections.Concurrent;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using NetPusula.Infrastructure;

namespace NetPusula.Tests;

internal sealed class AdjustableTimeProvider : TimeProvider
{
    private DateTimeOffset now = DateTimeOffset.UtcNow;
    public override DateTimeOffset GetUtcNow() => now;
    public void Advance(TimeSpan duration) => now += duration;
}

internal sealed class AuthApiFactory : WebApplicationFactory<Program>
{
    private readonly string path = Path.Combine(Path.GetTempPath(), $"netpusula-auth-{Guid.NewGuid():N}.db");
    private readonly int permitLimit;
    internal string Key { get; } = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
    internal AdjustableTimeProvider Clock { get; } = new();
    internal ConcurrentQueue<string> Logs { get; } = new();

    internal AuthApiFactory(int permitLimit = 500)
    {
        this.permitLimit = permitLimit;
        using var db = CreateDatabase();
        db.Database.EnsureCreated();
    }

    internal NetPusulaDbContext CreateDatabase() => new(new DbContextOptionsBuilder<NetPusulaDbContext>()
        .UseSqlite($"Data Source={path};Foreign Keys=True;Pooling=False;Default Timeout=30").Options);

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["Jwt:Issuer"] = "NetPusula.Tests",
                ["Jwt:Audience"] = "NetPusula.Tests.Client",
                ["Jwt:SigningKey"] = Key,
                ["Jwt:AccessTokenMinutes"] = "15",
                ["Auth:RefreshTokenDays"] = "30",
                ["AuthRateLimit:PermitLimit"] = permitLimit.ToString(),
                ["AuthRateLimit:WindowSeconds"] = "60"
            }));
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<NetPusulaDbContext>();
            services.AddScoped(_ => CreateDatabase());
            services.RemoveAll<TimeProvider>();
            services.AddSingleton<TimeProvider>(Clock);
        });
        builder.ConfigureLogging(logging => logging.AddProvider(new CaptureLoggerProvider(Logs)));
    }

    public override async ValueTask DisposeAsync()
    {
        await base.DisposeAsync();
        foreach (var suffix in new[] { "", "-wal", "-shm" })
            if (File.Exists(path + suffix)) File.Delete(path + suffix);
    }

    private sealed class CaptureLoggerProvider(ConcurrentQueue<string> logs) : ILoggerProvider
    {
        public ILogger CreateLogger(string categoryName) => new CaptureLogger(logs);
        public void Dispose() { }
    }

    private sealed class CaptureLogger(ConcurrentQueue<string> logs) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel logLevel) => true;
        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception,
            Func<TState, Exception?, string> formatter) => logs.Enqueue(formatter(state, exception) + exception);
    }
}

