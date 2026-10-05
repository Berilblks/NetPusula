using System.Text.Json.Serialization;
using NetPusula.Application.Dashboard;
namespace NetPusula.Application.Statistics;

public sealed record StatisticsComparison(bool SufficientData, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? RecentAverage, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? PreviousAverage, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? Change)
{
    public static StatisticsComparison From(Improvement value) => new(value.HasEnoughData,value.RecentAverage,value.PreviousAverage,value.Change);
}
public sealed record StatisticsRange(string Selection, int Limit, int AvailableAttemptCount, bool IsCapped);
public sealed record StatisticsSummary(int AttemptCount, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? LatestNet, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? AverageNet, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? BestNet, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? WorstNet);
public sealed record AnswerAverages([property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? Correct, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? Wrong, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? Blank);
public sealed record SectionPoint(Guid MockExamId, DateOnly TakenAt, int CorrectCount, int WrongCount, int BlankCount, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal Net);
public sealed record StatisticsSection(Guid ExamSectionId, string SectionCode, string SectionName, string? GroupCode, string? GroupName,
    bool IsActive, int QuestionCount, int AttemptCount, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? LatestNet, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? AverageNet, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? BestNet, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? WorstNet,
    List<SectionPoint> Series, AnswerAverages Answers, StatisticsComparison Improvement);
public sealed record StatisticsActivity(DateOnly? FirstMockDate, DateOnly? LastMockDate, int AttemptCount, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal? AverageDaysBetweenMocks);
public sealed record StatisticsDto([property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal TargetNet, StatisticsRange Range, StatisticsSummary Summary, List<DashboardPoint> Series,
    StatisticsComparison Improvement, DashboardPoint? BestMock, List<StatisticsSection> Sections, StatisticsActivity Activity);
public interface IStatisticsService { Task<StatisticsDto?> GetAsync(Guid userId, string range, CancellationToken ct); }
