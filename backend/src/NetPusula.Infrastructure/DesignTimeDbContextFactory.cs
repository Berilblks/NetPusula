using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace NetPusula.Infrastructure;

public sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<NetPusulaDbContext>
{
    public NetPusulaDbContext CreateDbContext(string[] args)
    {
        // Scaffold/script needs a provider, not a running database or real credentials.
        // Applying migrations requires ConnectionStrings__Database supplied by the operator.
        var connection = Environment.GetEnvironmentVariable("ConnectionStrings__Database")
            ?? "Host=localhost;Database=netpusula;Username=netpusula";
        return new NetPusulaDbContext(new DbContextOptionsBuilder<NetPusulaDbContext>()
            .UseNpgsql(connection).Options);
    }
}

