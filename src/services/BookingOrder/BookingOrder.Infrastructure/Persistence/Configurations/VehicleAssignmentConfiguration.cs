using BookingOrder.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BookingOrder.Infrastructure.Persistence.Configurations;

internal sealed class VehicleAssignmentConfiguration
    : IEntityTypeConfiguration<VehicleAssignment>
{
    public void Configure(EntityTypeBuilder<VehicleAssignment> builder)
    {
        builder.ToTable("vehicle_assignment");

        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).HasColumnName("id");

        builder.Property(x => x.BookingOrderId).HasColumnName("booking_order_id").IsRequired();
        builder.Property(x => x.BookingDetailId).HasColumnName("booking_detail_id").IsRequired();
        builder.Property(x => x.BookingCode).HasColumnName("booking_code").HasMaxLength(20).IsRequired();

        builder.Property(x => x.VehicleId).HasColumnName("vehicle_id").IsRequired();
        builder.Property(x => x.LicensePlate).HasColumnName("license_plate").HasMaxLength(15).IsRequired();
        builder.Property(x => x.VehicleType).HasColumnName("vehicle_type").HasMaxLength(20).IsRequired();
        builder.Property(x => x.VehicleCategory).HasColumnName("vehicle_category").HasMaxLength(30);
        builder.Property(x => x.Brand).HasColumnName("brand").HasMaxLength(50).IsRequired();
        builder.Property(x => x.Model).HasColumnName("model").HasMaxLength(50).IsRequired();
        builder.Property(x => x.VehicleYear).HasColumnName("vehicle_year");
        builder.Property(x => x.Color).HasColumnName("color").HasMaxLength(30);

        builder.Property(x => x.DriverId).HasColumnName("driver_id");
        builder.Property(x => x.DriverName).HasColumnName("driver_name").HasMaxLength(150);
        builder.Property(x => x.DriverPhone).HasColumnName("driver_phone").HasMaxLength(20);
        builder.Property(x => x.NfcCardUid).HasColumnName("nfc_card_uid").HasMaxLength(50);

        builder.Property(x => x.DispatchPoolId).HasColumnName("dispatch_pool_id").IsRequired();
        builder.Property(x => x.DispatchPoolName).HasColumnName("dispatch_pool_name").HasMaxLength(150).IsRequired();
        builder.Property(x => x.ReturnPoolId).HasColumnName("return_pool_id");
        builder.Property(x => x.ReturnPoolName).HasColumnName("return_pool_name").HasMaxLength(150);

        builder.Property(x => x.AssignedAt).HasColumnName("assigned_at").IsRequired();
        builder.Property(x => x.DispatchedAt).HasColumnName("dispatched_at");
        builder.Property(x => x.ReturnedAt).HasColumnName("returned_at");

        builder.Property(x => x.Status).HasColumnName("status")
            .HasConversion<string>().HasMaxLength(20).IsRequired();

        builder.Property(x => x.AssignmentStatus).HasColumnName("assignment_status").IsRequired();
        builder.Property(x => x.Sequence).HasColumnName("sequence").IsRequired();

        builder.Property(x => x.ReleaseReasonType).HasColumnName("release_reason_type");
        builder.Property(x => x.ReleaseReasonNote).HasColumnName("release_reason_note");
        builder.Property(x => x.ReleasedAt).HasColumnName("released_at");
        builder.Property(x => x.ReleasedBy).HasColumnName("released_by").HasMaxLength(100);

        builder.Property(x => x.TransactionId).HasColumnName("transaction_id").HasMaxLength(100).IsRequired();
        builder.Property(x => x.CreatedAt).HasColumnName("created_at");
        builder.Property(x => x.UpdatedAt).HasColumnName("updated_at");

        builder.HasIndex(x => x.VehicleId);
        builder.HasIndex(x => x.Status);
    }
}
