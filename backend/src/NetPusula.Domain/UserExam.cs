namespace NetPusula.Domain;

public sealed class UserExam : Entity
{
    private UserExam() { }
    public UserExam(User user, Exam exam, decimal targetNet, DateOnly examDate)
    {
        ArgumentNullException.ThrowIfNull(user);
        ArgumentNullException.ThrowIfNull(exam);
        UserId = user.Id;
        ExamId = exam.Id;
        TargetNet = Guard.Score(targetNet);
        ExamDate = examDate;
    }

    public Guid UserId { get; private set; }
    public Guid ExamId { get; private set; }
    public decimal TargetNet { get; private set; }
    public DateOnly ExamDate { get; private set; }
    public bool IsActive { get; private set; } = true;
    public void Deactivate() => IsActive = false;
}

