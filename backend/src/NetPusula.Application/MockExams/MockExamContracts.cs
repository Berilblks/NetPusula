using System.Text.Json.Serialization;
namespace NetPusula.Application.MockExams;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record MockResultRequest(Guid ExamSectionId, int CorrectCount, int WrongCount, int? BlankCount = null);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record SaveMockExamRequest(string? Name, DateOnly TakenAt, string? Notes, List<MockResultRequest>? Results);
public sealed record MockSummaryDto(Guid Id, string Name, DateOnly TakenAt, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal TotalNet, DateTime CreatedAtUtc);
public sealed record MockResultDto(Guid ExamSectionId, string SectionCode, string SectionName, string? GroupCode,
    string? GroupName, int QuestionCount, int CorrectCount, int WrongCount, int BlankCount, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal Net);
public sealed record MockDetailDto(Guid Id, string Name, DateOnly TakenAt, string? Notes, [property: JsonNumberHandling(JsonNumberHandling.WriteAsString | JsonNumberHandling.AllowReadingFromString)] decimal TotalNet, List<MockResultDto> Results);
public sealed record MockPageDto(List<MockSummaryDto> Items, int Page, int PageSize, int TotalCount, int TotalPages);
public enum MockFailure { None, Validation, NotFound, NoPreparation, Conflict }
public sealed record MockOutcome<T>(T? Value = default, MockFailure Failure = MockFailure.None);
public interface IMockExamService
{
    Task<MockOutcome<MockPageDto>> ListAsync(Guid user, int page, int pageSize, CancellationToken ct);
    Task<MockOutcome<MockDetailDto>> DetailAsync(Guid user, Guid id, CancellationToken ct);
    Task<MockOutcome<MockDetailDto>> SaveAsync(Guid user, Guid? id, SaveMockExamRequest request, CancellationToken ct);
    Task<MockOutcome<bool>> DeleteAsync(Guid user, Guid id, CancellationToken ct);
}
