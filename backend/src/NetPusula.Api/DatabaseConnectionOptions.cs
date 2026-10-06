using Npgsql;
namespace NetPusula.Api;

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
