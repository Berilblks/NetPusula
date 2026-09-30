using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using NetPusula.Infrastructure;

namespace NetPusula.Tests;

// Real relational constraints, isolated per test. Does not claim PostgreSQL migration coverage.
internal sealed class TestDatabase : IAsyncDisposable
{
    private readonly SqliteConnection connection = new("Data Source=:memory:;Foreign Keys=True");

    public TestDatabase()
    {
        connection.Open();
        using var db = CreateContext();
        db.Database.EnsureCreated();
    }

    public NetPusulaDbContext CreateContext() =>
        new(new DbContextOptionsBuilder<NetPusulaDbContext>().UseSqlite(connection).Options);

    public ValueTask DisposeAsync() => connection.DisposeAsync();
}

