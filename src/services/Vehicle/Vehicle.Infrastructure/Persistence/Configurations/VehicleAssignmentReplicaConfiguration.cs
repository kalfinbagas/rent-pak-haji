using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Vehicle.Domain.Entities;

namespace Vehicle.Infrastructure.Persistence.Configurations;

internal sealed class VehicleAssignmentReplicaConfiguration : IEntityTypeConfiguration<VehicleAssignmentReplica>
{
    public void Configure(EntityTypeBuilder<VehicleAssignmentReplica> b)
    {
        b.ToTable("vehicle_assignment");
        b.HasKey(x => x.Id);

        b.Property(x => x.Id).HasColumnName("id").ValueGeneratedNever(); // PK from source
        b.Property(x => x.BookingCode).HasColumnName("booking_code").HasMaxLength(20);
        b.Property(x => x.VehicleId).HasColumnName("vehicle_id");
        b.Property(x => x.LicensePlate).HasColumnName("license_plate").HasMaxLength(15);
        b.Property(x => x.VehicleType).HasColumnName("vehicle_type").HasMaxLength(20);
        b.Property(x => x.VehicleCategory).HasColumnName("vehicle_category").HasMaxLength(30);
        b.Property(x => x.Brand).HasColumnName("brand").HasMaxLength(50);
        b.Property(x => x.Model).HasColumnName("model").HasMaxLength(50);
        b.Property(x => x.DriverId).HasColumnName("driver_id");
        b.Property(x => x.DriverName).HasColumnName("driver_name").HasMaxLength(150);
        b.Property(x => x.NfcCardUid).HasColumnName("nfc_card_uid").HasMaxLength(50);
        b.Property(x => x.PoolLocationId).HasColumnName("pool_location_id");
        b.Property(x => x.PoolLocationName).HasColumnName("pool_location_name").HasMaxLength(150);
        b.Property(x => x.AssignedAt).HasColumnName("assigned_at");
        b.Property(x => x.Status).HasColumnName("status").HasConversion<string>().HasMaxLength(20);
        b.Property(x => x.AssignmentStatus).HasColumnName("assignment_status");
        b.Property(x => x.SyncedAt).HasColumnName("synced_at");
        b.Property(x => x.Sequence).HasColumnName("sequence");
        b.Property(x => x.TransactionId).HasColumnName("transaction_id").HasMaxLength(100);

        // FK to MasterVehicle — same DB
        b.HasOne(x => x.Vehicle)
            .WithMany()
            .HasForeignKey(x => x.VehicleId)
            .OnDelete(DeleteBehavior.Restrict);

        b.HasIndex(x => x.VehicleId).HasDatabaseName("idx_va_vehicle_rep");
        b.HasIndex(x => x.Status).HasDatabaseName("idx_va_status_rep");
        b.HasIndex(x => x.PoolLocationId).HasDatabaseName("idx_va_pool_rep");

        b.Ignore(x => x.DomainEvents);
    }
}
