using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using NetPusula.Infrastructure;

namespace NetPusula.Tests;

public sealed class PreparationMigrationTests
{
    [Fact]
    public async Task Migration_keeps_latest_active_and_preserves_all_historical_rows()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:;Foreign Keys=True");
        await connection.OpenAsync();
        await using var db = new NetPusulaDbContext(new DbContextOptionsBuilder<NetPusulaDbContext>().UseSqlite(connection).Options);
        var migrator = db.GetService<IMigrator>();
        await migrator.MigrateAsync("20260930115643_AddAuthentication");
        var userId = Guid.NewGuid(); var olderId = Guid.NewGuid(); var newerId = Guid.NewGuid();
        var examId = Guid.Parse("00000000-0000-0000-0000-000000000003");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"Users\" (\"Id\",\"Email\",\"NormalizedEmail\",\"DisplayName\",\"CreatedAtUtc\") VALUES ({userId},{"migration@example.test"},{"MIGRATION@EXAMPLE.TEST"},{"Migration"},{DateTime.UtcNow})");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"UserExams\" (\"Id\",\"UserId\",\"ExamId\",\"TargetNet\",\"ExamDate\",\"IsActive\",\"CreatedAtUtc\") VALUES ({olderId},{userId},{examId},{80m},{new DateOnly(2027,1,1)},{true},{new DateTime(2026,1,1,0,0,0,DateTimeKind.Utc)})");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"UserExams\" (\"Id\",\"UserId\",\"ExamId\",\"TargetNet\",\"ExamDate\",\"IsActive\",\"CreatedAtUtc\") VALUES ({newerId},{userId},{examId},{85m},{new DateOnly(2027,1,1)},{true},{new DateTime(2026,2,1,0,0,0,DateTimeKind.Utc)})");
        await migrator.MigrateAsync();
        await migrator.MigrateAsync(); // Reapplying is a no-op.
        Assert.Equal(2, await db.UserExams.CountAsync());
        Assert.Equal(newerId, (await db.UserExams.SingleAsync(x => x.IsActive)).Id);
        Assert.NotNull((await db.UserExams.SingleAsync(x => x.Id == olderId)).UpdatedAtUtc);
        Assert.True((await db.Exams.SingleAsync(x => x.Id == examId)).HasCompleteSectionConfiguration);
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync($"UPDATE \"UserExams\" SET \"IsActive\" = TRUE WHERE \"Id\" = {olderId}"));
    }
}
