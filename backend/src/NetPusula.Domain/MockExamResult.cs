namespace NetPusula.Domain;

public sealed class MockExamResult : Entity
{
    private MockExamResult() { }
    public MockExamResult(MockExam mockExam, ExamSection section, int correct, int wrong, int blank)
    {
        ArgumentNullException.ThrowIfNull(mockExam);
        ArgumentNullException.ThrowIfNull(section);
        if (mockExam.ExamId != section.ExamId)
            throw new ArgumentException("Section must belong to the preparation exam.");
        MockExamId = mockExam.Id;
        ExamSectionId = section.Id;
        ExamId = section.ExamId;
        SectionCodeSnapshot = section.Code;
        SectionNameSnapshot = section.Name;
        GroupCodeSnapshot = section.GroupCode;
        GroupNameSnapshot = section.GroupName;
        SortOrderSnapshot = section.SortOrder;
        QuestionCountSnapshot = section.QuestionCount;
        PenaltyDivisorSnapshot = section.PenaltyDivisor;
        SetAnswers(correct, wrong, blank);
    }

    public Guid MockExamId { get; private set; }
    public Guid ExamSectionId { get; private set; }
    public Guid ExamId { get; private set; }
    public int CorrectCount { get; private set; }
    public int WrongCount { get; private set; }
    public int BlankCount { get; private set; }
    public string SectionCodeSnapshot { get; private set; } = null!;
    public string SectionNameSnapshot { get; private set; } = null!;
    public string? GroupCodeSnapshot { get; private set; }
    public string? GroupNameSnapshot { get; private set; }
    public int SortOrderSnapshot { get; private set; }
    public int QuestionCountSnapshot { get; private set; }
    public decimal PenaltyDivisorSnapshot { get; private set; }
    public decimal Net => NetCalculator.Calculate(CorrectCount, WrongCount, BlankCount, QuestionCountSnapshot, PenaltyDivisorSnapshot);

    public void SetAnswers(int correct, int wrong, int blank)
    {
        _ = NetCalculator.Calculate(correct, wrong, blank, QuestionCountSnapshot, PenaltyDivisorSnapshot);
        CorrectCount = correct;
        WrongCount = wrong;
        BlankCount = blank;
    }
}

