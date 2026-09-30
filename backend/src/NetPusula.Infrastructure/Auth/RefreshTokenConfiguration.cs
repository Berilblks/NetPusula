using Microsoft.EntityFrameworkCore;
using NetPusula.Domain;

namespace NetPusula.Infrastructure.Auth;

internal static class RefreshTokenConfiguration
{
    internal static void Configure(ModelBuilder model)
    {
        var token = model.Entity<RefreshToken>();
        token.ToTable("RefreshTokens", table =>
        {
            table.HasCheckConstraint("CK_RefreshTokens_Expiry", "\"ExpiresAtUtc\" > \"CreatedAtUtc\"");
        });
        token.HasKey(x => x.Id);
        token.Property(x => x.Id).ValueGeneratedNever();
        token.Property(x => x.TokenHash).HasMaxLength(64).IsRequired();
        token.Property(x => x.CreatedAtUtc).HasColumnType("timestamp with time zone");
        token.Property(x => x.ExpiresAtUtc).HasColumnType("timestamp with time zone");
        token.Property(x => x.RevokedAtUtc).HasColumnType("timestamp with time zone").IsConcurrencyToken();
        token.HasIndex(x => x.TokenHash).IsUnique();
        token.HasIndex(x => x.UserId);
        token.HasIndex(x => x.ExpiresAtUtc);
        token.HasIndex(x => x.FamilyId);
        token.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        token.HasOne<RefreshToken>().WithMany().HasForeignKey(x => x.ReplacedByTokenId).OnDelete(DeleteBehavior.Restrict);
    }
}

