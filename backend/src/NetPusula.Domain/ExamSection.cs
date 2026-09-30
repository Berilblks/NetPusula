namespace NetPusula.Domain;

public sealed class ExamSection : Entity
{
    private ExamSection() { }
    public ExamSection(Exam exam, string code, string name, int questionCount, decimal penaltyDivisor,
        int sortOrder = 0, string? groupCode = null, string? groupName = null)
    {
        ArgumentNullException.ThrowIfNull(exam);
        ExamId = exam.Id;
        Code = Guard.Code(code);
        Name = Guard.Text(name, 200);
        ConfigureScoring(questionCount, penaltyDivisor);
        SortOrder = sortOrder;
        if ((groupCode is null) != (groupName is null))
            throw new ArgumentException("Group code and name must be supplied together.");
        GroupCode = groupCode is null ? null : Guard.Code(groupCode);
        GroupName = groupName is null ? null : Guard.Text(groupName, 200);
    }

    public Guid ExamId { get; private set; }
    public string Code { get; private set; } = null!;
    public string Name { get; private set; } = null!;
    public string? GroupCode { get; private set; }
    public string? GroupName { get; private set; }
    public int QuestionCount { get; private set; }
    public decimal PenaltyDivisor { get; private set; }
    public int SortOrder { get; private set; }
    public bool IsActive { get; private set; } = true;

    public void ConfigureScoring(int questionCount, decimal penaltyDivisor)
    {
        if (questionCount <= 0) throw new ArgumentOutOfRangeException(nameof(questionCount));
        var validatedDivisor = Guard.Divisor(penaltyDivisor);
        QuestionCount = questionCount;
        PenaltyDivisor = validatedDivisor;
    }
    public void Deactivate() => IsActive = false;
}

