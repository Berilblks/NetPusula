namespace NetPusula.Application.Exams;

public sealed record ExamDto(Guid Id, string Code, string Name, string? Description, int SortOrder);
public sealed record ExamSectionDto(Guid Id, Guid ExamId, string Code, string Name, string? GroupCode,
    string? GroupName, int QuestionCount, decimal PenaltyDivisor, int SortOrder);

