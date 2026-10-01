using Microsoft.EntityFrameworkCore;
using NetPusula.Application.Exams;
using NetPusula.Infrastructure;
using NetPusula.Infrastructure.Preparations;

namespace NetPusula.Api;

public static class ExamEndpoints
{
    public static void MapExamEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/exams").WithTags("Exams");
        group.MapGet("/", async (NetPusulaDbContext db, CancellationToken cancellationToken) =>
        {
            var exams = await db.Exams.AsNoTracking().Where(x => x.IsActive)
                .OrderBy(x => x.SortOrder).ThenBy(x => x.Code)
                .ToListAsync(cancellationToken);
            var result = new List<ExamDto>();
            foreach (var exam in exams)
                result.Add(new(exam.Id, exam.Code, exam.Name, exam.Description, exam.SortOrder,
                    await ExamTargetLimit.GetAsync(db, exam, cancellationToken)));
            return result;
        });

        group.MapGet("/{id:guid}", async (Guid id, NetPusulaDbContext db, CancellationToken cancellationToken) =>
        {
            var exam = await db.Exams.AsNoTracking().Where(x => x.Id == id && x.IsActive)
                .SingleOrDefaultAsync(cancellationToken);
            return exam is null ? Results.NotFound() : Results.Ok(new ExamDto(exam.Id, exam.Code, exam.Name,
                exam.Description, exam.SortOrder, await ExamTargetLimit.GetAsync(db, exam, cancellationToken)));
        });

        group.MapGet("/{id:guid}/sections", async (Guid id, NetPusulaDbContext db, CancellationToken cancellationToken) =>
        {
            if (!await db.Exams.AnyAsync(x => x.Id == id && x.IsActive, cancellationToken))
                return Results.NotFound();
            var sections = await db.ExamSections.AsNoTracking().Where(x => x.ExamId == id && x.IsActive)
                .OrderBy(x => x.SortOrder).ThenBy(x => x.Code)
                .Select(x => new ExamSectionDto(x.Id, x.ExamId, x.Code, x.Name, x.GroupCode,
                    x.GroupName, x.QuestionCount, x.PenaltyDivisor, x.SortOrder))
                .ToListAsync(cancellationToken);
            return Results.Ok(sections);
        });
    }
}

