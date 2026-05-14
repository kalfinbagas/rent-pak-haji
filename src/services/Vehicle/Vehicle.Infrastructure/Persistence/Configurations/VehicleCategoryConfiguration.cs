using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Vehicle.Domain.Entities;

namespace Vehicle.Infrastructure.Persistence.Configurations;

internal sealed class VehicleCategoryConfiguration : IEntityTypeConfiguration<VehicleCategory>
{
    public void Configure(EntityTypeBuilder<VehicleCategory> b)
    {
        b.ToTable("vehicle_category");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.Code).HasColumnName("code").HasMaxLength(20).IsRequired();
        b.Property(x => x.Name).HasColumnName("name").HasMaxLength(100).IsRequired();
        b.Property(x => x.VehicleType).HasColumnName("vehicle_type").HasMaxLength(20).IsRequired();
        b.Property(x => x.Description).HasColumnName("description");
        b.Property(x => x.IsActive).HasColumnName("is_active");
        b.Property(x => x.Version).HasColumnName("version").IsConcurrencyToken();
        b.Property(x => x.CreatedBy).HasColumnName("created_by").HasMaxLength(50);
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.Property(x => x.UpdatedBy).HasColumnName("modified_by").HasMaxLength(50);
        b.Property(x => x.UpdatedAt).HasColumnName("modified_at");

        b.HasIndex(x => x.Code).IsUnique().HasDatabaseName("uq_vehicle_category_code");
    }
}
