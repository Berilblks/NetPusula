namespace NetPusula.Domain;

public sealed class MockExam : Entity
{
    private MockExam() { }
    public MockExam(UserExam preparation, string name, DateTime takenAtUtc, string? notes = null)
    {
        ArgumentNullException.ThrowIfNull(preparation);
        if (takenAtUtc.Kind != DateTimeKind.Utc)
            throw new ArgumentException("TakenAtUtc must be UTC.", nameof(takenAtUtc));
        UserExamId = preparation.Id;
        ExamId = preparation.ExamId;
        Name = Guard.Text(name, 200);
        TakenAtUtc = takenAtUtc;
        Notes = notes is null ? null : Guard.Text(notes, 4000);
    }

    public Guid UserExamId { get; private set; }
    // Shared FK component enforces exam membership in the database.
    public Guid ExamId { get; private set; }
    public string Name { get; private set; } = null!;
    public DateTime TakenAtUtc { get; private set; }
    public string? Notes { get; private set; }
}

