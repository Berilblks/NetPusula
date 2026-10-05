using System.Data;
using Microsoft.EntityFrameworkCore;
using NetPusula.Application.Dashboard;
using NetPusula.Application.Statistics;
using NetPusula.Domain;
using NetPusula.Infrastructure.Analytics;
namespace NetPusula.Infrastructure.Statistics;

public sealed class StatisticsService(NetPusulaDbContext db) : IStatisticsService
{
    public const int AllLimit = 500;
    public async Task<StatisticsDto?> GetAsync(Guid userId, string range, CancellationToken ct)
    {
        var limit = range switch { "5" => 5, "10" => 10, "20" => 20, "all" => AllLimit, _ => throw new ArgumentException("Invalid range", nameof(range)) };
        await using var tx = await db.Database.BeginTransactionAsync(db.Database.IsNpgsql() ? IsolationLevel.RepeatableRead : IsolationLevel.Serializable, ct);
        var prep = await db.UserExams.AsNoTracking().Where(p => p.UserId == userId && p.IsActive)
            .Select(p => new { p.Id, p.ExamId, p.TargetNet }).SingleOrDefaultAsync(ct);
        if (prep is null) return null;
        var available = await db.MockExams.CountAsync(m => m.UserExamId == prep.Id, ct);
        var catalog = await db.ExamSections.AsNoTracking().Where(s => s.ExamId == prep.ExamId && s.IsActive)
            .OrderBy(s => s.SortOrder).ThenBy(s => s.Code)
            .Select(s => new { s.Id, s.Code, s.Name, s.GroupCode, s.GroupName, s.QuestionCount }).ToListAsync(ct);
        var sections = catalog.ToDictionary(s => s.Id, s => new Section(s.Id,s.Code,s.Name,s.GroupCode,s.GroupName,true,s.QuestionCount));
        // LIMIT applies to attempts BEFORE the result join, so no attempt is partially selected.
        var selected = db.MockExams.AsNoTracking().Where(m => m.UserExamId == prep.Id)
            .OrderByDescending(m => m.TakenAtUtc).ThenByDescending(m => m.CreatedAtUtc).ThenByDescending(m => m.Id)
            .Select(m => new { m.Id, m.Name, m.TakenAtUtc, m.CreatedAtUtc }).Take(limit);
        var rows = from m in selected
            join r in db.MockExamResults.AsNoTracking() on m.Id equals r.MockExamId into results
            from r in results.DefaultIfEmpty()
            orderby m.TakenAtUtc, m.CreatedAtUtc, m.Id, r.ExamSectionId
            select new { m.Id,m.Name,m.TakenAtUtc, SectionId=(Guid?)r.ExamSectionId,
                Correct=(int?)r.CorrectCount,Wrong=(int?)r.WrongCount,Blank=(int?)r.BlankCount,
                Questions=(int?)r.QuestionCountSnapshot,Divisor=(decimal?)r.PenaltyDivisorSnapshot,
                r.SectionCodeSnapshot,r.SectionNameSnapshot,r.GroupCodeSnapshot,r.GroupNameSnapshot };
        var totals = new DecimalAggregate();
        var series = new List<DashboardPoint>();
        DashboardPoint? best = null;
        Guid? id = null; string name = ""; DateOnly date = default; decimal total = 0;
        void Finish()
        {
            if (id is null) return;
            totals.Add(total);
            var point = new DashboardPoint(id.Value,name,date,total);
            series.Add(point);
            // Equal best nets choose the most recent attempt under the same chronological order.
            if (best is null || total >= best.TotalNet) best = point;
        }
        await foreach (var r in rows.AsAsyncEnumerable().WithCancellation(ct))
        {
            if (id != r.Id) { Finish(); id=r.Id;name=r.Name;date=DateOnly.FromDateTime(r.TakenAtUtc);total=0; }
            if (r.SectionId is not Guid sectionId) continue;
            var net = NetCalculator.Calculate(r.Correct!.Value,r.Wrong!.Value,r.Blank!.Value,r.Questions!.Value,r.Divisor!.Value);
            total += net;
            if (!sections.TryGetValue(sectionId,out var section))
            {
                section = new(sectionId,r.SectionCodeSnapshot,r.SectionNameSnapshot,r.GroupCodeSnapshot,r.GroupNameSnapshot,false,r.Questions.Value);
                sections.Add(sectionId,section);
            }
            if (!section.Active) section.Display(r.SectionCodeSnapshot,r.SectionNameSnapshot,r.GroupCodeSnapshot,r.GroupNameSnapshot,r.Questions.Value);
            section.Add(new(r.Id,date,r.Correct.Value,r.Wrong.Value,r.Blank.Value,net));
        }
        Finish();
        await tx.CommitAsync(ct);
        return new(prep.TargetNet,new(range,limit,available,range=="all" && available>limit),
            new(totals.Count,totals.Latest,totals.Average,totals.Best,totals.Worst),series,StatisticsComparison.From(totals.Comparison()),best,
            sections.Values.Select(s=>s.Dto()).ToList(),
            new(series.FirstOrDefault()?.TakenAt,series.LastOrDefault()?.TakenAt,totals.Count,
                totals.Count<2 ? null : (decimal)(series[^1].TakenAt.DayNumber-series[0].TakenAt.DayNumber)/(totals.Count-1)));
    }
    private sealed class Section(Guid id,string code,string name,string? groupCode,string? groupName,bool active,int questions)
    {
        public bool Active => active;
        private readonly DecimalAggregate values = new();
        private readonly List<SectionPoint> series = new();
        private decimal correct,wrong,blank;
        public void Display(string c,string n,string? gc,string? gn,int q) {code=c;name=n;groupCode=gc;groupName=gn;questions=q;}
        public void Add(SectionPoint point) {series.Add(point);values.Add(point.Net);correct+=point.CorrectCount;wrong+=point.WrongCount;blank+=point.BlankCount;}
        public StatisticsSection Dto() => new(id,code,name,groupCode,groupName,active,questions,values.Count,values.Latest,values.Average,values.Best,values.Worst,
            series,new(values.Count==0?null:correct/values.Count,values.Count==0?null:wrong/values.Count,values.Count==0?null:blank/values.Count),StatisticsComparison.From(values.Comparison()));
    }
}
