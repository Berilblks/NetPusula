namespace NetPusula.Domain;

public static class NetCalculator
{
    public static decimal Calculate(int correct, int wrong, int blank, int questionCount, decimal penaltyDivisor)
    {
        if (questionCount <= 0) throw new ArgumentOutOfRangeException(nameof(questionCount));
        if (penaltyDivisor <= 0) throw new ArgumentOutOfRangeException(nameof(penaltyDivisor));
        if (correct < 0 || wrong < 0 || blank < 0)
            throw new ArgumentOutOfRangeException(nameof(correct), "Answer counts cannot be negative.");
        if ((long)correct + wrong + blank > questionCount)
            throw new ArgumentException("Answer counts exceed the configured question count.");
        return correct - wrong / penaltyDivisor;
    }
}

