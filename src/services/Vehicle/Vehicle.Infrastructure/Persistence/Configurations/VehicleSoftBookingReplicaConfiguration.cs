using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Vehicle.Domain.Entities;

namespace Vehicle.Infrastructure.Persistence.Configurations;

internal sealed class VehicleSoftBookingReplicaConfiguration : IEntityTypeConfiguration<VehicleSoftBookingReplica>
{
    public void Configure(EntityTypeBuilder<VehicleSoftBookingReplica> b)
    {
        b.ToTable("vehicle_soft_booking");
        b.HasKey(x => x.Id);

        b.Property(x => x.Id).HasColumnName("id").ValueGeneratedNever(); // PK from source
        b.Property(x => x.BookingCode).HasColumnName("booking_code").HasMaxLength(20);
        b.Property(x => x.BookingDetailId).HasColumnName("booking_detail_id");
        b.Property(x => x.VehicleType).HasColumnName("vehicle_type").HasMaxLength(20);
        b.Property(x => x.PoolLocationId).HasColumnName("pool_location_id");
        b.Property(x => x.PoolLocationName).HasColumnName("pool_location_name").HasMaxLength(150);
        b.Property(x => x.StartRentalAt).HasColumnName("start_rental_at");
        b.Property(x => x.EndRentalAt).HasColumnName("end_rental_at");
        b.Property(x => x.ExpiresAt).HasColumnName("expires_at");
        b.Property(x => x.Status).HasColumnName("status").HasConversion<string>().HasMaxLength(20);
        b.Property(x => x.NumberOfVehicles).HasColumnName("number_of_vehicles");
        b.Property(x => x.SyncedAt).HasColumnName("synced_at");
        b.Property(x => x.Sequence).HasColumnName("sequence");
        b.Property(x => x.TransactionId).HasColumnName("transaction_id").HasMaxLength(100);

        b.HasIndex(x => new { x.PoolLocationId, x.VehicleType }).HasDatabaseName("idx_vsb_pool_type");
        b.HasIndex(x => x.Status).HasDatabaseName("idx_vsb_status_rep");

        b.Ignore(x => x.DomainEvents);
    }
}
