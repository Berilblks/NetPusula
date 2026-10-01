using Microsoft.EntityFrameworkCore;
using NetPusula.Application.MockExams;
using NetPusula.Application.Preparations;
using NetPusula.Domain;
namespace NetPusula.Infrastructure.MockExams;

public sealed class MockExamService(NetPusulaDbContext db, TimeProvider clock) : IMockExamService
{
    private IQueryable<MockExam> Owned(Guid user) => db.MockExams.Where(m => db.UserExams.Any(p => p.Id == m.UserExamId && p.UserId == user));
    public async Task<MockOutcome<MockPageDto>> ListAsync(Guid user, int page, int pageSize, CancellationToken ct)
    {
        if (page < 1 || pageSize < 1 || pageSize > 100 || (long)(page - 1) * pageSize > int.MaxValue)
            return new(Failure: MockFailure.Validation);
        var active = await db.UserExams.AsNoTracking().SingleOrDefaultAsync(p => p.UserId == user && p.IsActive, ct);
        if (active is null) return new(Failure: MockFailure.NoPreparation);
        var query = db.MockExams.AsNoTracking().Where(m => m.UserExamId == active.Id);
        var count = await query.CountAsync(ct);
        var rows = await query.OrderByDescending(m => m.TakenAtUtc).ThenByDescending(m => m.CreatedAtUtc).ThenByDescending(m => m.Id)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        var ids = rows.Select(m => m.Id).ToArray();
        var results = await db.MockExamResults.AsNoTracking().Where(r => ids.Contains(r.MockExamId)).ToListAsync(ct);
        return new(new(rows.Select(m => new MockSummaryDto(m.Id, m.Name, DateOnly.FromDateTime(m.TakenAtUtc),
            results.Where(r => r.MockExamId == m.Id).Sum(r => r.Net), m.CreatedAtUtc)).ToList(), page, pageSize, count, (int)Math.Ceiling((decimal)count / pageSize)));
    }
    public async Task<MockOutcome<MockDetailDto>> DetailAsync(Guid user, Guid id, CancellationToken ct)
    {
        var row = await Owned(user).AsNoTracking().SingleOrDefaultAsync(m => m.Id == id, ct);
        return row is null ? new(Failure: MockFailure.NotFound) : new(await Detail(row, ct));
    }
    public async Task<MockOutcome<MockDetailDto>> SaveAsync(Guid user, Guid? id, SaveMockExamRequest request, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Shared with preparation changes: resolve and save against one stable active preparation.
        if (db.Database.IsNpgsql())
            await db.Users.FromSqlInterpolated($"SELECT * FROM \"Users\" WHERE \"Id\" = {user} FOR UPDATE").ToListAsync(ct);
        MockExam? row = null;
        List<MockExamResult> existing = [];
        UserExam? preparation = null;
        if (id is not null)
        {
            row = await Owned(user).SingleOrDefaultAsync(m => m.Id == id, ct);
            if (row is null) return new(Failure: MockFailure.NotFound);
            existing = await db.MockExamResults.Where(r => r.MockExamId == id).ToListAsync(ct);
        }
        else
        {
            preparation = await db.UserExams.SingleOrDefaultAsync(p => p.UserId == user && p.IsActive, ct);
            if (preparation is null) return new(Failure: MockFailure.NoPreparation);
        }
        if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Trim().Length > 200 || request.Notes?.Length > 4000 ||
            request.TakenAt == default || request.TakenAt > PreparationRules.Today(clock.GetUtcNow()) ||
            request.Results is not { Count: > 0 and <= 100 } || request.Results.Any(r => r is null) ||
            request.Results.Select(r => r.ExamSectionId).Distinct().Count() != request.Results.Count)
            return new(Failure: MockFailure.Validation);
        var sections = id is null ? await db.ExamSections.AsNoTracking().Where(s => s.ExamId == preparation!.ExamId && s.IsActive)
            .OrderBy(s => s.SortOrder).ToListAsync(ct) : [];
        if (id is null && (!await db.Exams.AnyAsync(e => e.Id == preparation!.ExamId && e.IsActive, ct) || sections.Count == 0))
            return new(Failure: MockFailure.Conflict);
        // Full replacement of counts, never a replacement of the historical section set.
        var expected = id is null ? sections.Select(s => s.Id).ToHashSet() : existing.Select(r => r.ExamSectionId).ToHashSet();
        if (!expected.SetEquals(request.Results.Select(r => r.ExamSectionId))) return new(Failure: MockFailure.Validation);
        foreach (var answer in request.Results)
        {
            var questions = id is null ? sections.Single(s => s.Id == answer.ExamSectionId).QuestionCount
                : existing.Single(r => r.ExamSectionId == answer.ExamSectionId).QuestionCountSnapshot;
            var blank = (long)questions - answer.CorrectCount - answer.WrongCount;
            if (answer.CorrectCount < 0 || answer.WrongCount < 0 || blank < 0 || (answer.BlankCount is int supplied && supplied != blank))
                return new(Failure: MockFailure.Validation);
        }
        var date = request.TakenAt.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim();
        if (row is null)
        {
            row = new MockExam(preparation!, request.Name.Trim(), date, notes);
            db.MockExams.Add(row);
            foreach (var answer in request.Results)
            {
                var section = sections.Single(s => s.Id == answer.ExamSectionId);
                db.MockExamResults.Add(new MockExamResult(row, section, answer.CorrectCount, answer.WrongCount,
                    section.QuestionCount - answer.CorrectCount - answer.WrongCount));
            }
        }
        else
        {
            row.Update(request.Name.Trim(), date, notes);
            foreach (var answer in request.Results)
            {
                var result = existing.Single(r => r.ExamSectionId == answer.ExamSectionId);
                result.SetAnswers(answer.CorrectCount, answer.WrongCount, result.QuestionCountSnapshot - answer.CorrectCount - answer.WrongCount);
            }
        }
        await db.SaveChangesAsync(ct);
        var dto = await Detail(row, ct);
        await tx.CommitAsync(ct);
        return new(dto);
    }
    public async Task<MockOutcome<bool>> DeleteAsync(Guid user, Guid id, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        if (db.Database.IsNpgsql())
            await db.Users.FromSqlInterpolated($"SELECT * FROM \"Users\" WHERE \"Id\" = {user} FOR UPDATE").ToListAsync(ct);
        var row = await Owned(user).SingleOrDefaultAsync(m => m.Id == id, ct);
        if (row is null) return new(Failure: MockFailure.NotFound);
        db.MockExamResults.RemoveRange(await db.MockExamResults.Where(r => r.MockExamId == id).ToListAsync(ct));
        await db.SaveChangesAsync(ct);
        db.MockExams.Remove(row);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new(true);
    }
    private async Task<MockDetailDto> Detail(MockExam row, CancellationToken ct)
    {
        var results = await db.MockExamResults.AsNoTracking().Where(r => r.MockExamId == row.Id)
            .OrderBy(r => r.SortOrderSnapshot).ThenBy(r => r.SectionCodeSnapshot).ToListAsync(ct);
        return new(row.Id, row.Name, DateOnly.FromDateTime(row.TakenAtUtc), row.Notes, results.Sum(r => r.Net),
            results.Select(r => new MockResultDto(r.ExamSectionId, r.SectionCodeSnapshot, r.SectionNameSnapshot,
                r.GroupCodeSnapshot, r.GroupNameSnapshot, r.QuestionCountSnapshot, r.CorrectCount, r.WrongCount, r.BlankCount, r.Net)).ToList());
    }
}
