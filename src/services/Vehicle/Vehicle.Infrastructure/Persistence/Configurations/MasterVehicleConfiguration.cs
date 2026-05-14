using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Vehicle.Domain.Entities;
using Vehicle.Domain.Enums;

namespace Vehicle.Infrastructure.Persistence.Configurations;

internal sealed class MasterVehicleConfiguration : IEntityTypeConfiguration<MasterVehicle>
{
    public void Configure(EntityTypeBuilder<MasterVehicle> b)
    {
        b.ToTable("master_vehicle");
        b.HasKey(x => x.Id);

        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.LicensePlate).HasColumnName("license_plate").HasMaxLength(15).IsRequired();
        b.Property(x => x.Vin).HasColumnName("vin").HasMaxLength(20);
        b.Property(x => x.VehicleType).HasColumnName("vehicle_type").HasMaxLength(20).IsRequired();
        b.Property(x => x.Brand).HasColumnName("brand").HasMaxLength(50).IsRequired();
        b.Property(x => x.Model).HasColumnName("model").HasMaxLength(50).IsRequired();
        b.Property(x => x.Year).HasColumnName("year");
        b.Property(x => x.Color).HasColumnName("color").HasMaxLength(30);

        b.Property(x => x.VehicleCategoryId).HasColumnName("vehicle_category_id");
        b.Property(x => x.TransmissionTypeId).HasColumnName("transmission_type_id");
        b.Property(x => x.NumberOfSeats).HasColumnName("number_of_seats");
        b.Property(x => x.NumberOfDoors).HasColumnName("number_of_doors");
        b.Property(x => x.FuelType).HasColumnName("fuel_type").HasMaxLength(20);
        b.Property(x => x.WheelDrive).HasColumnName("wheel_drive").HasMaxLength(10);

        b.Property(x => x.Status)
            .HasColumnName("status")
            .HasConversion(
                v => v.ToString().ToUpperInvariant()
                       .Replace("INUSE","IN_USE")
                       .Replace("RETURNINGSOON","RETURNING_SOON")
                       .Replace("LATERETURN","LATE_RETURN"),
                v => Enum.Parse<VehicleStatus>(v.Replace("_",""), ignoreCase: true));

        b.Property(x => x.PoolLocationId).HasColumnName("pool_location_id");
        b.Property(x => x.PoolLocationName).HasColumnName("pool_location_name").HasMaxLength(150);
        b.Property(x => x.DailyRate).HasColumnName("daily_rate").HasPrecision(18, 2);
        b.Property(x => x.Odometer).HasColumnName("odometer");
        b.Property(x => x.HasObd).HasColumnName("has_obd");

        b.Property(x => x.PreparationStatus).HasColumnName("preparation_status")
            .HasConversion<string?>()
            .IsRequired(false);
        b.Property(x => x.PreparationActivity).HasColumnName("preparation_activity").HasMaxLength(100);
        b.Property(x => x.PreparationActivityStatus).HasColumnName("preparation_activity_status").HasMaxLength(20);
        b.Property(x => x.PreparationPic).HasColumnName("preparation_pic");

        b.Property(x => x.ConditionInMaintenance).HasColumnName("condition_in_maintenance");
        b.Property(x => x.ConditionHasBreakdown).HasColumnName("condition_has_breakdown");
        b.Property(x => x.ConditionHasOutstanding).HasColumnName("condition_has_outstanding");

        b.Property(x => x.PoolInTargetTime).HasColumnName("pool_in_target_time");
        b.Property(x => x.PoolInActualTime).HasColumnName("pool_in_actual_time");

        b.Property(x => x.OwnershipType)
            .HasColumnName("ownership_type")
            .HasConversion<string>()
            .HasMaxLength(20);
        b.Property(x => x.ValidFrom).HasColumnName("valid_from");
        b.Property(x => x.ValidTo).HasColumnName("valid_to");
        b.Property(x => x.AcquisitionDate).HasColumnName("acquisition_date");
        b.Property(x => x.AcquisitionValue).HasColumnName("acquisition_value").HasPrecision(18, 2);
        b.Property(x => x.ExternalRef).HasColumnName("external_ref").HasMaxLength(100);
        b.Property(x => x.TransactionId).HasColumnName("transaction_id").HasMaxLength(100);

        b.Property(x => x.IsActive).HasColumnName("is_active");
        b.Property(x => x.Version).HasColumnName("version").IsConcurrencyToken();
        b.Property(x => x.CreatedBy).HasColumnName("created_by").HasMaxLength(50);
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.Property(x => x.UpdatedBy).HasColumnName("modified_by").HasMaxLength(50);
        b.Property(x => x.UpdatedAt).HasColumnName("modified_at");

        b.HasIndex(x => x.LicensePlate).IsUnique().HasDatabaseName("uq_master_vehicle_plate");
        b.HasIndex(x => x.Status).HasDatabaseName("idx_mv_status");
        b.HasIndex(x => x.PoolLocationId).HasDatabaseName("idx_mv_pool");
        b.HasIndex(x => x.VehicleType).HasDatabaseName("idx_mv_type");

        // Navigation: movements (one-to-many, no cascade delete — audit trail is permanent)
        b.HasMany(x => x.Movements)
            .WithOne()
            .HasForeignKey(m => m.VehicleId)
            .OnDelete(DeleteBehavior.Restrict);

        // Ignore in-memory domain events list
        b.Ignore(x => x.DomainEvents);
    }
}
