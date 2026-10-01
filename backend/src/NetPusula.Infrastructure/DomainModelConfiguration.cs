using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using NetPusula.Domain;

namespace NetPusula.Infrastructure;

internal static class DomainModelConfiguration
{
    private static EntityTypeBuilder<T> Base<T>(ModelBuilder model, string table) where T : Entity
    {
        var entity = model.Entity<T>();
        entity.ToTable(table);
        entity.HasKey(x => x.Id);
        entity.Property(x => x.Id).ValueGeneratedNever();
        entity.Property(x => x.CreatedAtUtc).HasColumnType("timestamp with time zone");
        entity.Property(x => x.UpdatedAtUtc).HasColumnType("timestamp with time zone");
        return entity;
    }

    internal static void Configure(ModelBuilder model)
    {
        var user = Base<User>(model, "Users");
        user.Property(x => x.Email).HasMaxLength(320).IsRequired();
        user.Property(x => x.NormalizedEmail).HasMaxLength(320).IsRequired();
        user.Property(x => x.DisplayName).HasMaxLength(120).IsRequired();
        user.Property(x => x.PasswordHash).HasMaxLength(1024);
        user.HasIndex(x => x.NormalizedEmail).IsUnique();

        var exam = Base<Exam>(model, "Exams");
        exam.Property(x => x.Code).HasMaxLength(64).IsRequired();
        exam.Property(x => x.Name).HasMaxLength(200).IsRequired();
        exam.Property(x => x.Description).HasMaxLength(2000);
        exam.HasIndex(x => x.Code).IsUnique();
        exam.HasIndex(x => new { x.IsActive, x.SortOrder });

        var section = Base<ExamSection>(model, "ExamSections");
        section.Property(x => x.Code).HasMaxLength(64).IsRequired();
        section.Property(x => x.Name).HasMaxLength(200).IsRequired();
        section.Property(x => x.GroupCode).HasMaxLength(64);
        section.Property(x => x.GroupName).HasMaxLength(200);
        section.Property(x => x.PenaltyDivisor).HasPrecision(10, 4);
        section.HasIndex(x => new { x.ExamId, x.Code }).IsUnique();
        section.HasIndex(x => new { x.ExamId, x.IsActive, x.SortOrder });
        section.HasAlternateKey(x => new { x.Id, x.ExamId });
        section.HasOne<Exam>().WithMany().HasForeignKey(x => x.ExamId).OnDelete(DeleteBehavior.Restrict);
        section.ToTable(t =>
        {
            t.HasCheckConstraint("CK_ExamSections_QuestionCount", "\"QuestionCount\" > 0");
            t.HasCheckConstraint("CK_ExamSections_PenaltyDivisor", "\"PenaltyDivisor\" > 0");
            t.HasCheckConstraint("CK_ExamSections_Group", "(\"GroupCode\" IS NULL AND \"GroupName\" IS NULL) OR (\"GroupCode\" IS NOT NULL AND \"GroupName\" IS NOT NULL)");
        });

        var preparation = Base<UserExam>(model, "UserExams");
        preparation.Property(x => x.TargetNet).HasPrecision(12, 4);
        preparation.Property(x => x.ExamDate).HasColumnType("date");
        preparation.HasAlternateKey(x => new { x.Id, x.ExamId });
        preparation.HasIndex(x => new { x.UserId, x.IsActive });
        preparation.HasIndex(x => x.UserId).IsUnique().HasFilter("\"IsActive\" = TRUE")
            .HasDatabaseName("UX_UserExams_OneActivePerUser");
        preparation.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        preparation.HasOne<Exam>().WithMany().HasForeignKey(x => x.ExamId).OnDelete(DeleteBehavior.Restrict);
        preparation.ToTable(t => t.HasCheckConstraint("CK_UserExams_TargetNet", "\"TargetNet\" >= 0"));

        var mock = Base<MockExam>(model, "MockExams");
        mock.Property(x => x.Name).HasMaxLength(200).IsRequired();
        mock.Property(x => x.Notes).HasMaxLength(4000);
        mock.Property(x => x.TakenAtUtc).HasColumnType("timestamp with time zone");
        mock.HasAlternateKey(x => new { x.Id, x.ExamId });
        mock.HasIndex(x => new { x.UserExamId, x.TakenAtUtc });
        mock.HasOne<UserExam>().WithMany().HasForeignKey(x => new { x.UserExamId, x.ExamId })
            .HasPrincipalKey(x => new { x.Id, x.ExamId }).OnDelete(DeleteBehavior.Restrict);

        var result = Base<MockExamResult>(model, "MockExamResults");
        result.Ignore(x => x.Net);
        result.Property(x => x.PenaltyDivisorSnapshot).HasPrecision(10, 4);
        result.HasIndex(x => new { x.MockExamId, x.ExamSectionId }).IsUnique();
        result.HasOne<MockExam>().WithMany().HasForeignKey(x => new { x.MockExamId, x.ExamId })
            .HasPrincipalKey(x => new { x.Id, x.ExamId }).OnDelete(DeleteBehavior.Restrict);
        result.HasOne<ExamSection>().WithMany().HasForeignKey(x => new { x.ExamSectionId, x.ExamId })
            .HasPrincipalKey(x => new { x.Id, x.ExamId }).OnDelete(DeleteBehavior.Restrict);
        result.ToTable(t =>
        {
            t.HasCheckConstraint("CK_MockExamResults_Counts", "\"CorrectCount\" >= 0 AND \"WrongCount\" >= 0 AND \"BlankCount\" >= 0");
            t.HasCheckConstraint("CK_MockExamResults_QuestionCount", "\"QuestionCountSnapshot\" > 0 AND CAST(\"CorrectCount\" AS bigint) + \"WrongCount\" + \"BlankCount\" <= \"QuestionCountSnapshot\"");
            t.HasCheckConstraint("CK_MockExamResults_PenaltyDivisor", "\"PenaltyDivisorSnapshot\" > 0");
        });
    }
}

