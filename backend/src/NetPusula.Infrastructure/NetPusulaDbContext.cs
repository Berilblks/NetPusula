using Microsoft.EntityFrameworkCore;
using NetPusula.Domain;

namespace NetPusula.Infrastructure;

public sealed class NetPusulaDbContext(DbContextOptions<NetPusulaDbContext> options) : DbContext(options)
{
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<User> Users => Set<User>();
    public DbSet<Exam> Exams => Set<Exam>();
    public DbSet<ExamSection> ExamSections => Set<ExamSection>();
    public DbSet<UserExam> UserExams => Set<UserExam>();
    public DbSet<MockExam> MockExams => Set<MockExam>();
    public DbSet<MockExamResult> MockExamResults => Set<MockExamResult>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        DomainModelConfiguration.Configure(modelBuilder);
        Auth.RefreshTokenConfiguration.Configure(modelBuilder);
        ExamSeed.Configure(modelBuilder);
    }

    private void PrepareChanges()
    {
        var now = DateTime.UtcNow;
        foreach (var entry in ChangeTracker.Entries<Entity>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Property(x => x.CreatedAtUtc).CurrentValue = now;
                entry.Property(x => x.UpdatedAtUtc).CurrentValue = null;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Property(x => x.CreatedAtUtc).IsModified = false;
                entry.Property(x => x.UpdatedAtUtc).CurrentValue = now;
            }
        }
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        PrepareChanges();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        PrepareChanges();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }
}


