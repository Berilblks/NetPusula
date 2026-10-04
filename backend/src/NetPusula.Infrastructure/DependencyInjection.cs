using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace NetPusula.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddScoped<NetPusula.Application.Dashboard.IDashboardService, Dashboard.DashboardService>();
        services.AddScoped<NetPusula.Application.MockExams.IMockExamService, MockExams.MockExamService>();
        services.AddScoped<NetPusula.Application.Preparations.IPreparationService, Preparations.PreparationService>();
        services.AddDbContext<NetPusulaDbContext>(options =>
        {
            var connection = configuration.GetConnectionString("Database");
            if (string.IsNullOrWhiteSpace(connection))
                throw new InvalidOperationException("Configure ConnectionStrings:Database before accessing the database.");
            options.UseNpgsql(connection);
        });
        return services;
    }
}

