using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using NetPusula.Infrastructure;
namespace NetPusula.Tests;
public sealed class MockMigrationTests
{
    [Fact] public async Task Snapshot_migration_backfills_display_without_replacing_numeric_history()
    {
        await using var connection=new SqliteConnection("Data Source=:memory:;Foreign Keys=True");await connection.OpenAsync();
        await using var db=new NetPusulaDbContext(new DbContextOptionsBuilder<NetPusulaDbContext>().UseSqlite(connection).Options);
        var migrator=db.GetService<IMigrator>();await migrator.MigrateAsync("20260930173315_EnforceSingleActiveUserExam");
        var user=Guid.NewGuid();var prep=Guid.NewGuid();var mock=Guid.NewGuid();var result=Guid.NewGuid();var exam=Guid.Parse("00000000-0000-0000-0000-000000000003");
        var section=await db.ExamSections.FirstAsync(s=>s.ExamId==exam);var now=DateTime.UtcNow;
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"Users\" (\"Id\",\"Email\",\"NormalizedEmail\",\"DisplayName\",\"CreatedAtUtc\") VALUES ({user},{"migration@example.test"},{"MIGRATION@EXAMPLE.TEST"},{"Test"},{now})");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"UserExams\" (\"Id\",\"UserId\",\"ExamId\",\"TargetNet\",\"ExamDate\",\"IsActive\",\"CreatedAtUtc\") VALUES ({prep},{user},{exam},{80m},{new DateOnly(2027,1,1)},{true},{now})");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"MockExams\" (\"Id\",\"UserExamId\",\"ExamId\",\"Name\",\"TakenAtUtc\",\"CreatedAtUtc\") VALUES ({mock},{prep},{exam},{"Old"},{now},{now})");
        await db.Database.ExecuteSqlInterpolatedAsync($"INSERT INTO \"MockExamResults\" (\"Id\",\"MockExamId\",\"ExamSectionId\",\"ExamId\",\"CorrectCount\",\"WrongCount\",\"BlankCount\",\"QuestionCountSnapshot\",\"PenaltyDivisorSnapshot\",\"CreatedAtUtc\") VALUES ({result},{mock},{section.Id},{exam},{20},{4},{16},{40},{3m},{now})");
        await migrator.MigrateAsync();await migrator.MigrateAsync();
        var row=await db.MockExamResults.SingleAsync();Assert.Equal(section.Name,row.SectionNameSnapshot);Assert.Equal(section.Code,row.SectionCodeSnapshot);Assert.Equal(40,row.QuestionCountSnapshot);Assert.Equal(3,row.PenaltyDivisorSnapshot);Assert.Equal(20-4/3m,row.Net);
    }
}
