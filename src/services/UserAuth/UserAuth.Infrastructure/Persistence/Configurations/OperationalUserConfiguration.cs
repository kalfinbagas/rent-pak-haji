using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using UserAuth.Domain.Entities;

namespace UserAuth.Infrastructure.Persistence.Configurations;

internal sealed class OperationalUserConfiguration : IEntityTypeConfiguration<OperationalUser>
{
    public void Configure(EntityTypeBuilder<OperationalUser> builder)
    {
        builder.ToTable("operational_user");

        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).HasColumnName("id");

        builder.Property(x => x.FullName)
            .HasColumnName("full_name")
            .HasMaxLength(150)
            .IsRequired();

        builder.Property(x => x.DateOfBirth)
            .HasColumnName("date_of_birth")
            .HasColumnType("date")
            .HasConversion(
                d => d.ToDateTime(TimeOnly.MinValue),
                d => DateOnly.FromDateTime(d))
            .IsRequired();

        builder.Property(x => x.Address)
            .HasColumnName("address")
            .HasMaxLength(500)
            .IsRequired();

        builder.Property(x => x.PhoneNumber)
            .HasColumnName("phone_number")
            .HasMaxLength(20)
            .IsRequired();

        builder.Property(x => x.Email)
            .HasColumnName("email")
            .HasMaxLength(150)
            .IsRequired();

        builder.Property(x => x.PasswordHash)
            .HasColumnName("password_hash")
            .IsRequired();

        builder.Property(x => x.KtpPhotoPath)
            .HasColumnName("ktp_photo_path")
            .IsRequired();

        builder.Property(x => x.Role)
            .HasColumnName("role")
            .HasConversion<string>()
            .HasMaxLength(20)
            .IsRequired();

        // Audit columns
        builder.Property(x => x.CreatedAt).HasColumnName("created_at");
        builder.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        builder.Property(x => x.CreatedBy).HasColumnName("created_by");
        builder.Property(x => x.UpdatedBy).HasColumnName("updated_by");
        builder.Property(x => x.IsActive).HasColumnName("is_active");
        builder.Property(x => x.Version).HasColumnName("version").IsConcurrencyToken();

        // Unique index
        builder.HasIndex(x => x.Email).IsUnique();
    }
}
