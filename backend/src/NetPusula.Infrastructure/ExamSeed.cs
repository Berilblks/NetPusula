using Microsoft.EntityFrameworkCore;
using NetPusula.Domain;

namespace NetPusula.Infrastructure;

// Versioned model-managed reference data: change this catalogue with a reviewed EF migration.
// Never delete/reassign existing IDs; deactivate retired configurations instead.
internal static class ExamSeed
{
    private static readonly DateTime Created = new(2026, 9, 29, 0, 0, 0, DateTimeKind.Utc);
    private static Guid Id(int value) => Guid.Parse($"00000000-0000-0000-0000-{value:D12}");

    internal static void Configure(ModelBuilder model)
    {
        var exams = new[]
        {
            (1, "YKS", "Yükseköğretim Kurumları Sınavı"),
            (2, "KPSS", "Kamu Personel Seçme Sınavı"),
            (3, "ALES", "Akademik Personel ve Lisansüstü Eğitimi Giriş Sınavı"),
            (4, "DGS", "Dikey Geçiş Sınavı"),
            (5, "MSU", "Millî Savunma Üniversitesi Askerî Öğrenci Aday Belirleme Sınavı"),
            (6, "YDS", "Yabancı Dil Bilgisi Seviye Tespit Sınavı")
        };
        foreach (var (number, code, name) in exams)
            model.Entity<Exam>().HasData(new
            {
                Id = Id(number),
                Code = code,
                Name = name,
                IsActive = true,
                SortOrder = number * 10,
                CreatedAtUtc = Created
            });

        // ÖSYM 2026 ALES guide, sections 3.1 and 3.9; see docs/architecture.md.
        model.Entity<ExamSection>().HasData(
            new
            {
                Id = Id(301),
                ExamId = Id(3),
                Code = "SAYISAL",
                Name = "Sayısal",
                QuestionCount = 50,
                PenaltyDivisor = 4m,
                SortOrder = 10,
                IsActive = true,
                CreatedAtUtc = Created
            },
            new
            {
                Id = Id(302),
                ExamId = Id(3),
                Code = "SOZEL",
                Name = "Sözel",
                QuestionCount = 50,
                PenaltyDivisor = 4m,
                SortOrder = 20,
                IsActive = true,
                CreatedAtUtc = Created
            });
    }
}

