using Npgsql;
namespace NetPusula.Api;

public static class DatabaseConnectionValidation
{
    public static IServiceCollection AddDatabaseConnectionValidation(
        this IServiceCollection services, IHostEnvironment environment)
    {
        services.AddOptions<DatabaseConnectionOptions>().BindConfiguration("ConnectionStrings")
            .Validate(x => environment.IsDevelopment() || x.IsValid(),
                "Configure a valid database connection with explicit host and database before starting outside Development.")
            .ValidateOnStart();
        return services;
    }
}

public sealed class DatabaseConnectionOptions
{
    public string Database { get; set; } = "";
    public bool IsValid()
    {
        if (string.IsNullOrWhiteSpace(Database)) return false;
        try
        {
            var connection = new NpgsqlConnectionStringBuilder(Database);
            return !string.IsNullOrWhiteSpace(connection.Host) && !string.IsNullOrWhiteSpace(connection.Database);
        }
        catch (ArgumentException) { return false; }
    }
}
