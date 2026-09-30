namespace NetPusula.Domain;

public abstract class Entity
{
    public Guid Id { get; private set; } = Guid.NewGuid();
    public DateTime CreatedAtUtc { get; private set; } = DateTime.UtcNow;
    public DateTime? UpdatedAtUtc { get; private set; }
}

internal static class Guard
{
    internal static string Text(string value, int maxLength)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(value);
        value = value.Trim();
        if (value.Length > maxLength) throw new ArgumentOutOfRangeException(nameof(value));
        return value;
    }

    internal static string Code(string value) => Text(value, 64).ToUpperInvariant();

    internal static decimal Score(decimal value)
    {
        if (value < 0 || value > 99999999.9999m || decimal.Round(value, 4) != value)
            throw new ArgumentOutOfRangeException(nameof(value));
        return value;
    }

    internal static decimal Divisor(decimal value)
    {
        if (value <= 0 || value > 999999.9999m || decimal.Round(value, 4) != value)
            throw new ArgumentOutOfRangeException(nameof(value));
        return value;
    }
}

