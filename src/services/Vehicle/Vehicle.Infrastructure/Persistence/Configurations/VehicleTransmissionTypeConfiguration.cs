using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Vehicle.Domain.Entities;

namespace Vehicle.Infrastructure.Persistence.Configurations;

internal sealed class VehicleTransmissionTypeConfiguration : IEntityTypeConfiguration<VehicleTransmissionType>
{
    public void Configure(EntityTypeBuilder<VehicleTransmissionType> b)
    {
        b.ToTable("vehicle_transmission_type");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.Code).HasColumnName("code").HasMaxLength(20).IsRequired();
        b.Property(x => x.Name).HasColumnName("name").HasMaxLength(50).IsRequired();
        b.Property(x => x.IsActive).HasColumnName("is_active");
        b.Property(x => x.Version).HasColumnName("version").IsConcurrencyToken();
        b.Property(x => x.CreatedBy).HasColumnName("created_by").HasMaxLength(50);
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.Property(x => x.UpdatedBy).HasColumnName("modified_by").HasMaxLength(50);
        b.Property(x => x.UpdatedAt).HasColumnName("modified_at");

        b.HasIndex(x => x.Code).IsUnique().HasDatabaseName("uq_transmission_type_code");
    }
}
