using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using NetPusula.Domain;

namespace NetPusula.Tests;

public sealed class DatabaseTests
{
    [Theory]
    [InlineData("exam")]
    [InlineData("section")]
    [InlineData("email")]
    public async Task Unique_keys_reject_duplicates(string kind)
    {
        await using var database = new TestDatabase();
        await using var db = database.CreateContext();
        if (kind == "exam") db.Exams.Add(new Exam(" ales ", "Duplicate"));
        else if (kind == "section")
        {
            var exam = await db.Exams.SingleAsync(x => x.Code == "ALES");
            db.ExamSections.Add(new ExamSection(exam, "sayisal", "Duplicate", 50, 4));
        }
        else
        {
            db.Users.Add(new User(" person@example.test ", "One"));
            await db.SaveChangesAsync();
            db.Users.Add(new User("PERSON@example.test", "Two"));
        }
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }

    [Fact]
    public async Task Result_constraints_membership_history_and_timestamps_are_enforced()
    {
        await using var database = new TestDatabase();
        await using var db = database.CreateContext();
        var exam = await db.Exams.SingleAsync(x => x.Code == "ALES");
        var section = await db.ExamSections.FirstAsync(x => x.ExamId == exam.Id);
        var user = new User("test@example.test", "Test");
        var preparation = new UserExam(user, exam, 38, new DateOnly(2027, 1, 1));
        var mock = new MockExam(preparation, "Practice", DateTime.UtcNow);
        var result = new MockExamResult(mock, section, 40, 8, 2);
        db.AddRange(user, preparation, mock, result);
        await db.SaveChangesAsync();
        var created = result.CreatedAtUtc;
        Assert.Equal(DateTimeKind.Utc, created.Kind);
        Assert.Null(result.UpdatedAtUtc);
        result.SetAnswers(39, 9, 2);
        await db.SaveChangesAsync();
        Assert.Equal(created, result.CreatedAtUtc);
        Assert.NotNull(result.UpdatedAtUtc);
        Assert.Equal(DateTimeKind.Utc, result.UpdatedAtUtc.Value.Kind);
        db.MockExamResults.Add(new MockExamResult(mock, section, 0, 0, 50));
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        db.ChangeTracker.Clear();

        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE \"MockExamResults\" SET \"CorrectCount\" = {-1} WHERE \"Id\" = {result.Id}"));
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE \"MockExamResults\" SET \"CorrectCount\" = {51} WHERE \"Id\" = {result.Id}"));
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE \"MockExamResults\" SET \"PenaltyDivisorSnapshot\" = {0} WHERE \"Id\" = {result.Id}"));

        var other = await db.Exams.SingleAsync(x => x.Code == "YKS");
        var otherSection = new ExamSection(other, "TYT_TEST", "Test fixture, not official seed", 40, 4, groupCode: "TYT", groupName: "TYT");
        db.ExamSections.Add(otherSection);
        await db.SaveChangesAsync();
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE \"MockExamResults\" SET \"ExamSectionId\" = {otherSection.Id} WHERE \"Id\" = {result.Id}"));
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE \"MockExams\" SET \"ExamId\" = {other.Id} WHERE \"Id\" = {mock.Id}"));
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"DELETE FROM \"Users\" WHERE \"Id\" = {user.Id}"));
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"DELETE FROM \"UserExams\" WHERE \"Id\" = {preparation.Id}"));
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"DELETE FROM \"MockExams\" WHERE \"Id\" = {mock.Id}"));
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"DELETE FROM \"ExamSections\" WHERE \"Id\" = {section.Id}"));
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"DELETE FROM \"Exams\" WHERE \"Id\" = {exam.Id}"));

        var loadedSection = await db.ExamSections.SingleAsync(x => x.Id == section.Id);
        loadedSection.ConfigureScoring(100, 2);
        await db.SaveChangesAsync();
        var loadedResult = await db.MockExamResults.SingleAsync(x => x.Id == result.Id);
        Assert.Equal(36.75m, loadedResult.Net);
        Assert.Null(db.Model.FindEntityType(typeof(MockExamResult))!.FindProperty("Net"));
        // A new preparation does not overwrite the old one or its results.
        var previous = await db.UserExams.SingleAsync(x => x.Id == preparation.Id);
        previous.Deactivate();
        await db.SaveChangesAsync();
        db.UserExams.Add(new UserExam(user, other, 10, new DateOnly(2028, 1, 1)));
        await db.SaveChangesAsync();
        Assert.Equal(2, await db.UserExams.CountAsync());
        Assert.Equal(1, await db.MockExamResults.CountAsync());
    }

    [Fact]
    public async Task Seed_is_repeatable_and_configuration_checks_are_relational()
    {
        await using var database = new TestDatabase();
        await using var db = database.CreateContext();
        Assert.False(await db.Database.EnsureCreatedAsync());
        Assert.Equal(6, await db.Exams.CountAsync());
        Assert.Equal(2, await db.ExamSections.CountAsync());
        var section = await db.ExamSections.FirstAsync();
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE \"ExamSections\" SET \"PenaltyDivisor\" = {0} WHERE \"Id\" = {section.Id}"));
        await Assert.ThrowsAsync<SqliteException>(() => db.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE \"ExamSections\" SET \"QuestionCount\" = {0} WHERE \"Id\" = {section.Id}"));
        Assert.All(db.Model.GetEntityTypes().SelectMany(x => x.GetForeignKeys()),
            fk => Assert.Equal(DeleteBehavior.Restrict, fk.DeleteBehavior));
    }
}

