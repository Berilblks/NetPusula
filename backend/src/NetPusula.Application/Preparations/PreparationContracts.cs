using System.Text.Json.Serialization;

namespace NetPusula.Application.Preparations;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record CreatePreparationRequest(Guid ExamId, decimal TargetNet, DateOnly ExamDate);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record UpdatePreparationRequest(decimal TargetNet, DateOnly ExamDate);
public sealed record PreparationExamDto(Guid Id, string Code, string Name, decimal? MaximumTargetNet);
public sealed record PreparationDto(Guid Id, PreparationExamDto Exam, decimal TargetNet, DateOnly ExamDate,
    DateTime CreatedAtUtc, DateTime? UpdatedAtUtc);
public enum PreparationFailure { None, Validation, NotFound, Conflict }
public sealed record PreparationResult(PreparationDto? Value = null,
    PreparationFailure Failure = PreparationFailure.None, Dictionary<string, string[]>? Errors = null);
public interface IPreparationService
{
    Task<PreparationDto?> ActiveAsync(Guid userId, CancellationToken ct);
    Task<PreparationResult> CreateAsync(Guid userId, CreatePreparationRequest request, CancellationToken ct);
    Task<PreparationResult> UpdateAsync(Guid userId, Guid id, UpdatePreparationRequest request, CancellationToken ct);
}
public static class PreparationRules
{
    // The product's MVP calendar is Turkey (UTC+03), independent of untrusted device clocks.
    public static DateOnly Today(DateTimeOffset utcNow) => DateOnly.FromDateTime(utcNow.ToOffset(TimeSpan.FromHours(3)).DateTime);
    public static Dictionary<string, string[]> Validate(decimal target, DateOnly date, decimal? maximum, DateOnly today)
    {
        var errors = new Dictionary<string, string[]>();
        // numeric(12,4) representation limit, NOT an official exam maximum.
        if (target <= 0 || target > 99999999.9999m || decimal.Round(target, 4) != target || (maximum.HasValue && target > maximum))
            errors["targetNet"] = ["Provide a positive target within the configured range, with at most four decimal places."];
        if (date < today) errors["examDate"] = ["The date cannot be in the past in the Turkey calendar."];
        return errors;
    }
}
