using System.Data;
using Microsoft.EntityFrameworkCore;
using NetPusula.Application.Dashboard;
using NetPusula.Application.Preparations;
using NetPusula.Domain;
namespace NetPusula.Infrastructure.Dashboard;

public sealed class DashboardService(NetPusulaDbContext db, TimeProvider clock) : IDashboardService
{
    public const int TrendLimit = 20;
    public async Task<DashboardDto?> GetAsync(Guid userId, CancellationToken ct)
    {
        // One consistent snapshot across preparation, catalogue, and result projections.
        await using var tx = await db.Database.BeginTransactionAsync(db.Database.IsNpgsql() ? IsolationLevel.RepeatableRead : IsolationLevel.Serializable, ct);
        var prep = await (from p in db.UserExams.AsNoTracking() join e in db.Exams.AsNoTracking() on p.ExamId equals e.Id
            where p.UserId == userId && p.IsActive
            select new { p.Id, p.ExamId, p.TargetNet, p.ExamDate, e.Code, e.Name }).SingleOrDefaultAsync(ct);
        if (prep is null) return null;
        var sections = await db.ExamSections.AsNoTracking().Where(s => s.ExamId == prep.ExamId && s.IsActive)
            .OrderBy(s => s.SortOrder).ThenBy(s => s.Code)
            .Select(s => new { s.Id, s.Code, s.Name, s.GroupCode, s.GroupName, s.QuestionCount }).ToListAsync(ct);
        var stats = sections.ToDictionary(s => s.Id, s => new SectionAccumulator(s.Id,s.Code,s.Name,s.GroupCode,s.GroupName,true,s.QuestionCount));
        // Project and stream scalars, NOT EF entities. Decimal division stays in the existing
        // NetCalculator: PostgreSQL numeric division and SQLite SQL arithmetic otherwise differ
        // from .NET decimal for non-terminating divisors. Memory is bounded by sections + 20 points.
        var query = from m in db.MockExams.AsNoTracking()
            where m.UserExamId == prep.Id
            join r in db.MockExamResults.AsNoTracking() on m.Id equals r.MockExamId into answers
            from r in answers.DefaultIfEmpty()
            orderby m.TakenAtUtc, m.CreatedAtUtc, m.Id
            select new { m.Id, m.Name, m.TakenAtUtc, SectionId = (Guid?)r.ExamSectionId,
                Correct = (int?)r.CorrectCount, Wrong = (int?)r.WrongCount, Blank = (int?)r.BlankCount,
                Questions = (int?)r.QuestionCountSnapshot, Divisor = (decimal?)r.PenaltyDivisorSnapshot,
                r.SectionCodeSnapshot, r.SectionNameSnapshot, r.GroupCodeSnapshot, r.GroupNameSnapshot };
        var totals = new Accumulator();
        var recent = new Queue<DashboardPoint>();
        Guid? current = null; string name = ""; DateOnly date = default; decimal total = 0;
        void Finish()
        {
            if (current is null) return;
            totals.Add(total);
            recent.Enqueue(new(current.Value, name, date, total));
            if (recent.Count > TrendLimit) recent.Dequeue();
        }
        await foreach (var row in query.AsAsyncEnumerable().WithCancellation(ct))
        {
            if (current != row.Id)
            {
                Finish(); current = row.Id; name = row.Name; date = DateOnly.FromDateTime(row.TakenAtUtc); total = 0;
            }
            if (row.SectionId is not Guid sectionId) continue;
            var net = NetCalculator.Calculate(row.Correct!.Value,row.Wrong!.Value,row.Blank!.Value,row.Questions!.Value,row.Divisor!.Value);
            total += net;
            if (!stats.TryGetValue(sectionId,out var section))
            {
                section = new(sectionId,row.SectionCodeSnapshot,row.SectionNameSnapshot,row.GroupCodeSnapshot,row.GroupNameSnapshot,false,row.Questions.Value);
                stats.Add(sectionId,section);
            }
            if (!section.IsActive) section.SetDisplay(row.SectionCodeSnapshot,row.SectionNameSnapshot,row.GroupCodeSnapshot,row.GroupNameSnapshot,row.Questions.Value);
            section.Values.Add(net);
        }
        Finish();
        var trend = recent.ToList();
        var newest = trend.AsEnumerable().Reverse().ToList();
        var enough = totals.Count >= 6;
        decimal? lastThree = enough ? newest.Take(3).Average(p => p.TotalNet) : null;
        decimal? previousThree = enough ? newest.Skip(3).Take(3).Average(p => p.TotalNet) : null;
        var today = PreparationRules.Today(clock.GetUtcNow());
        var days = prep.ExamDate.DayNumber - today.DayNumber;
        await tx.CommitAsync(ct);
        return new(new(prep.Id,prep.ExamId,prep.Code,prep.Name,prep.TargetNet,prep.ExamDate,Math.Max(0,days),days<0?"past":days==0?"today":"future"),
            new(totals.Count,totals.Latest,totals.Average,totals.Best,prep.TargetNet-totals.Latest),newest.Take(3).ToList(),trend,
            stats.Values.Select(s => s.Dto()).ToList(),new(enough,lastThree,previousThree,lastThree-previousThree));
    }
    private sealed class Accumulator
    {
        public int Count { get; private set; }
        private decimal sum;
        public decimal? Latest { get; private set; }
        public decimal? Best { get; private set; }
        public decimal? Average => Count==0 ? null : sum/Count;
        public void Add(decimal value) { Count++; sum+=value; Latest=value; Best=Best is null?value:Math.Max(Best.Value,value); }
    }
    private sealed class SectionAccumulator(Guid id,string code,string name,string? groupCode,string? groupName,bool active,int questions)
    {
        public bool IsActive => active;
        public Accumulator Values { get; } = new();
        public void SetDisplay(string c,string n,string? gc,string? gn,int q) { code=c;name=n;groupCode=gc;groupName=gn;questions=q; }
        public SectionPerformance Dto() => new(id,code,name,groupCode,groupName,active,questions,Values.Count,Values.Latest,Values.Average,Values.Best);
    }
}
