using BookingOrder.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BookingOrder.Infrastructure.Persistence.Configurations;

internal sealed class VehicleSoftBookingConfiguration
    : IEntityTypeConfiguration<VehicleSoftBooking>
{
    public void Configure(EntityTypeBuilder<VehicleSoftBooking> builder)
    {
        builder.ToTable("vehicle_soft_booking");

        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).HasColumnName("id");

        builder.Property(x => x.BookingOrderId).HasColumnName("booking_order_id").IsRequired();
        builder.Property(x => x.BookingCode).HasColumnName("booking_code").HasMaxLength(20).IsRequired();

        builder.Property(x => x.VehicleType).HasColumnName("vehicle_type").HasMaxLength(20).IsRequired();
        builder.Property(x => x.PoolLocationId).HasColumnName("pool_location_id").IsRequired();
        builder.Property(x => x.PoolLocationName).HasColumnName("pool_location_name").HasMaxLength(150).IsRequired();

        builder.Property(x => x.StartRentalAt).HasColumnName("start_rental_at").IsRequired();
        builder.Property(x => x.EndRentalAt).HasColumnName("end_rental_at").IsRequired();
        builder.Property(x => x.NumberOfVehicles).HasColumnName("number_of_vehicles").IsRequired();
        builder.Property(x => x.ExpiresAt).HasColumnName("expires_at").IsRequired();

        builder.Property(x => x.Status).HasColumnName("status")
            .HasConversion<string>().HasMaxLength(20).IsRequired();

        builder.Property(x => x.Sequence).HasColumnName("sequence").IsRequired();
        builder.Property(x => x.TransactionId).HasColumnName("transaction_id").HasMaxLength(100).IsRequired();

        builder.Property(x => x.CreatedAt).HasColumnName("created_at");
        builder.Property(x => x.UpdatedAt).HasColumnName("updated_at");

        builder.HasIndex(x => new { x.PoolLocationId, x.VehicleType });
        builder.HasIndex(x => x.Status);
        builder.HasIndex(x => x.ExpiresAt);
    }
}
