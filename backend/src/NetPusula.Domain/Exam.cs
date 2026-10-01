namespace NetPusula.Domain;

public sealed class Exam : Entity
{
    private Exam() { }
    public Exam(string code, string name, int sortOrder = 0, string? description = null)
    {
        Code = Guard.Code(code);
        Name = Guard.Text(name, 200);
        Description = description is null ? null : Guard.Text(description, 2000);
        SortOrder = sortOrder;
    }

    public string Code { get; private set; } = null!;
    public string Name { get; private set; } = null!;
    public string? Description { get; private set; }
    public bool IsActive { get; private set; } = true;
    // Catalogue maintainers must explicitly verify completeness; section presence alone is insufficient.
    public bool HasCompleteSectionConfiguration { get; private set; }
    public int SortOrder { get; private set; }
    public void Deactivate() => IsActive = false;
}

