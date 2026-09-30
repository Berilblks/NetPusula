using NetPusula.Domain;

namespace NetPusula.Tests;

public sealed class NetCalculatorTests
{
    [Fact]
    public void Calculates_divisor_rule() => Assert.Equal(38m, NetCalculator.Calculate(40, 8, 2, 50, 4m));

    [Fact]
    public void All_blank_is_zero() => Assert.Equal(0m, NetCalculator.Calculate(0, 0, 50, 50, 4m));

    [Theory]
    [InlineData(-1, 0, 0)]
    [InlineData(0, -1, 0)]
    [InlineData(0, 0, -1)]
    public void Rejects_negative_counts(int correct, int wrong, int blank) =>
        Assert.Throws<ArgumentOutOfRangeException>(() => NetCalculator.Calculate(correct, wrong, blank, 50, 4m));

    [Theory]
    [InlineData(40, 8, 3, 50)]
    [InlineData(int.MaxValue, 1, 0, int.MaxValue)]
    public void Rejects_excess_counts_without_integer_overflow(int correct, int wrong, int blank, int count) =>
        Assert.Throws<ArgumentException>(() => NetCalculator.Calculate(correct, wrong, blank, count, 4m));

    [Theory]
    [InlineData(0)]
    [InlineData(-4)]
    public void Rejects_invalid_divisor(int divisor) =>
        Assert.Throws<ArgumentOutOfRangeException>(() => NetCalculator.Calculate(0, 0, 50, 50, divisor));

    [Fact]
    public void Preserves_decimal_precision_and_negative_nets()
    {
        Assert.Equal(10m - 1m / 3m, NetCalculator.Calculate(10, 1, 0, 50, 3m));
        Assert.Equal(-2m, NetCalculator.Calculate(0, 8, 42, 50, 4m));
        Assert.Equal(6m, NetCalculator.Calculate(10, 8, 0, 50, 2m));
    }

    [Fact]
    public void Rejects_invalid_question_count() =>
        Assert.Throws<ArgumentOutOfRangeException>(() => NetCalculator.Calculate(0, 0, 0, 0, 4m));

    [Fact]
    public void Snapshots_preserve_history_and_reject_mismatched_exams()
    {
        var user = new User("test@example.test", "Test");
        var exam = new Exam("test", "Test");
        var section = new ExamSection(exam, "math", "Math", 50, 4);
        var mock = new MockExam(new UserExam(user, exam, 38, new DateOnly(2027, 1, 1)), "Test", DateTime.UtcNow);
        var result = new MockExamResult(mock, section, 40, 8, 2);
        section.ConfigureScoring(100, 2);
        Assert.Equal(38m, result.Net);
        Assert.Equal(50, result.QuestionCountSnapshot);
        Assert.Throws<ArgumentException>(() => result.SetAnswers(50, 1, 0));
        Assert.Throws<ArgumentException>(() => new MockExamResult(mock,
            new ExamSection(new Exam("other", "Other"), "math", "Math", 50, 4), 0, 0, 50));
        Assert.Throws<ArgumentException>(() => new MockExam(new UserExam(user, exam, 0, new DateOnly(2027, 1, 1)),
            "Test", DateTime.SpecifyKind(DateTime.Now, DateTimeKind.Unspecified)));
    }
}

