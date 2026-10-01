using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using NetPusula.Application.Preparations;
using NetPusula.Domain;
using Npgsql;

namespace NetPusula.Infrastructure.Preparations;

public static class ExamTargetLimit
{
    public static async Task<decimal?> GetAsync(NetPusulaDbContext db, Exam exam, CancellationToken ct)
    {
        if (!exam.HasCompleteSectionConfiguration) return null;
        var sections = await db.ExamSections.AsNoTracking().Where(x => x.ExamId == exam.Id).ToListAsync(ct);
        // Missing/retired/grouped configurations cannot safely claim a single complete total.
        return sections.Count > 0 && sections.All(x => x.IsActive && x.GroupCode == null)
            ? sections.Sum(x => (decimal)x.QuestionCount) : null;
    }
}

public sealed class PreparationService(NetPusulaDbContext db, TimeProvider clock) : IPreparationService
{
    public async Task<PreparationDto?> ActiveAsync(Guid userId, CancellationToken ct)
    {
        var row = await db.UserExams.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == userId && x.IsActive, ct);
        return row is null ? null : await DtoAsync(row, ct);
    }

    public async Task<PreparationResult> CreateAsync(Guid userId, CreatePreparationRequest request, CancellationToken ct)
    {
        try
        {
            await using var tx = await db.Database.BeginTransactionAsync(ct);
            var user = await LockUserAsync(userId, ct);
            if (user is null) return new(Failure: PreparationFailure.NotFound);
            var exam = await db.Exams.SingleOrDefaultAsync(x => x.Id == request.ExamId && x.IsActive, ct);
            if (exam is null) return new(Failure: PreparationFailure.NotFound);
            var errors = PreparationRules.Validate(request.TargetNet, request.ExamDate,
                await ExamTargetLimit.GetAsync(db, exam, ct), PreparationRules.Today(clock.GetUtcNow()));
            if (errors.Count > 0) return new(Failure: PreparationFailure.Validation, Errors: errors);
            var current = await db.UserExams.SingleOrDefaultAsync(x => x.UserId == userId && x.IsActive, ct);
            // Retry after a lost POST response (or concurrent identical submissions) is a no-op.
            if (current is not null && current.ExamId == request.ExamId && current.TargetNet == request.TargetNet && current.ExamDate == request.ExamDate)
            {
                await tx.CommitAsync(ct);
                return new(await DtoAsync(current, ct));
            }
            if (current is not null)
            {
                current.Deactivate();
                await db.SaveChangesAsync(ct); // Release partial-index slot before inserting, in the SAME transaction.
            }
            var row = new UserExam(user, exam, request.TargetNet, request.ExamDate);
            db.UserExams.Add(row);
            await db.SaveChangesAsync(ct);
            var dto = await DtoAsync(row, ct);
            await tx.CommitAsync(ct);
            return new(dto);
        }
        catch (DbUpdateException e) when (IsConflict(e.InnerException)) { return new(Failure: PreparationFailure.Conflict); }
        catch (DbException e) when (IsConflict(e)) { return new(Failure: PreparationFailure.Conflict); }
    }

    public async Task<PreparationResult> UpdateAsync(Guid userId, Guid id, UpdatePreparationRequest request, CancellationToken ct)
    {
        try
        {
            await using var tx = await db.Database.BeginTransactionAsync(ct);
            if (await LockUserAsync(userId, ct) is null) return new(Failure: PreparationFailure.NotFound);
            // Same response for nonexistent and somebody else's IDs; never reveal ownership.
            var row = await db.UserExams.SingleOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
            if (row is null) return new(Failure: PreparationFailure.NotFound);
            if (!row.IsActive) return new(Failure: PreparationFailure.Conflict);
            var exam = await db.Exams.SingleAsync(x => x.Id == row.ExamId, ct);
            var errors = PreparationRules.Validate(request.TargetNet, request.ExamDate,
                await ExamTargetLimit.GetAsync(db, exam, ct), PreparationRules.Today(clock.GetUtcNow()));
            if (errors.Count > 0) return new(Failure: PreparationFailure.Validation, Errors: errors);
            row.UpdateGoal(request.TargetNet, request.ExamDate);
            await db.SaveChangesAsync(ct);
            var dto = await DtoAsync(row, ct);
            await tx.CommitAsync(ct);
            return new(dto);
        }
        catch (DbUpdateException e) when (IsConflict(e.InnerException)) { return new(Failure: PreparationFailure.Conflict); }
        catch (DbException e) when (IsConflict(e)) { return new(Failure: PreparationFailure.Conflict); }
    }

    private async Task<User?> LockUserAsync(Guid userId, CancellationToken ct)
    {
        if (db.Database.IsNpgsql())
        {
            var users = await db.Users.FromSqlInterpolated($"SELECT * FROM \"Users\" WHERE \"Id\" = {userId} FOR UPDATE").ToListAsync(ct);
            return users.SingleOrDefault();
        }
        if (db.Database.ProviderName != "Microsoft.EntityFrameworkCore.Sqlite") throw new NotSupportedException("Unsupported preparation database provider.");
        // SQLite is test-only; its write transaction plus the partial unique index prevents double-active rows.
        return await db.Users.SingleOrDefaultAsync(x => x.Id == userId, ct);
    }
    private async Task<PreparationDto> DtoAsync(UserExam row, CancellationToken ct)
    {
        var exam = await db.Exams.AsNoTracking().SingleAsync(x => x.Id == row.ExamId, ct);
        return new(row.Id, new(exam.Id, exam.Code, exam.Name, await ExamTargetLimit.GetAsync(db, exam, ct)),
            row.TargetNet, row.ExamDate, row.CreatedAtUtc, row.UpdatedAtUtc);
    }
    private static bool IsConflict(Exception? e) => e is PostgresException { SqlState: "23505" or "40001" or "40P01" }
        || (e is DbException && e.GetType().Name == "SqliteException" &&
            e.GetType().GetProperty("SqliteErrorCode")?.GetValue(e) is int code && code is 5 or 6 or 19);
}
