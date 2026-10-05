using NetPusula.Application.Dashboard;
namespace NetPusula.Infrastructure.Analytics;

// Shared exact-decimal summaries and Phase 7's last-three versus previous-three rule.
internal sealed class DecimalAggregate
{
    private decimal sum;
    private readonly Queue<decimal> recent = new();
    public int Count { get; private set; }
    public decimal? Latest { get; private set; }
    public decimal? Best { get; private set; }
    public decimal? Worst { get; private set; }
    public decimal? Average => Count == 0 ? null : sum / Count;
    public void Add(decimal value)
    {
        Count++; sum += value; Latest = value;
        Best = Best is null ? value : Math.Max(Best.Value, value);
        Worst = Worst is null ? value : Math.Min(Worst.Value, value);
        recent.Enqueue(value);
        if (recent.Count > 6) recent.Dequeue();
    }
    public Improvement Comparison()
    {
        if (Count < 6) return new(false, null, null, null);
        var values = recent.ToArray();
        var previous = (values[0] + values[1] + values[2]) / 3;
        var latest = (values[3] + values[4] + values[5]) / 3;
        return new(true, latest, previous, latest - previous);
    }
}
