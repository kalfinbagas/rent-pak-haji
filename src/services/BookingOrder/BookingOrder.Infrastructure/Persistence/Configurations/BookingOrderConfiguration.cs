using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BookingOrder.Infrastructure.Persistence.Configurations;

internal sealed class BookingOrderConfiguration
    : IEntityTypeConfiguration<Domain.Entities.BookingOrder>
{
    public void Configure(EntityTypeBuilder<Domain.Entities.BookingOrder> builder)
    {
        builder.ToTable("booking_order");

        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).HasColumnName("id");

        builder.Property(x => x.BookingCode).HasColumnName("booking_code").HasMaxLength(20).IsRequired();
        builder.HasIndex(x => x.BookingCode).IsUnique();

        builder.Property(x => x.Status).HasColumnName("status")
            .HasConversion<string>().HasMaxLength(30).IsRequired();

        builder.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
        builder.Property(x => x.CustomerName).HasColumnName("customer_name").HasMaxLength(150).IsRequired();
        builder.Property(x => x.CustomerPhone).HasColumnName("customer_phone").HasMaxLength(20).IsRequired();
        builder.Property(x => x.CustomerEmail).HasColumnName("customer_email").HasMaxLength(150);

        builder.Property(x => x.ServiceType).HasColumnName("service_type")
            .HasConversion<string>().HasMaxLength(20).IsRequired();

        builder.Property(x => x.VehicleType).HasColumnName("vehicle_type").HasMaxLength(20).IsRequired();
        builder.Property(x => x.VehicleCategory).HasColumnName("vehicle_category").HasMaxLength(30);
        builder.Property(x => x.NumberOfVehicles).HasColumnName("number_of_vehicles").IsRequired();

        builder.Property(x => x.StartRentalAt).HasColumnName("start_rental_at").IsRequired();
        builder.Property(x => x.EndRentalAt).HasColumnName("end_rental_at").IsRequired();
        builder.Property(x => x.DurationDays).HasColumnName("duration_days");
        builder.Property(x => x.WithDriverDurationHours).HasColumnName("with_driver_duration_hours");
        builder.Property(x => x.IsOutOfTown).HasColumnName("is_out_of_town").IsRequired();

        builder.Property(x => x.DailyRate).HasColumnName("daily_rate").HasPrecision(18, 2).IsRequired();
        builder.Property(x => x.SubtotalRental).HasColumnName("subtotal_rental").HasPrecision(18, 2).IsRequired();
        builder.Property(x => x.SubtotalAmount).HasColumnName("subtotal_amount").HasPrecision(18, 2).IsRequired();
        builder.Property(x => x.TaxAmount).HasColumnName("tax_amount").HasPrecision(18, 2).IsRequired();
        builder.Property(x => x.TotalAmount).HasColumnName("total_amount").HasPrecision(18, 2).IsRequired();

        builder.Property(x => x.VoucherCode).HasColumnName("voucher_code").HasMaxLength(50);
        builder.Property(x => x.VoucherDiscount).HasColumnName("voucher_discount").HasPrecision(18, 2);
        builder.Property(x => x.HasSpecialPrice).HasColumnName("has_special_price");

        builder.Property(x => x.AssignedVehicleId).HasColumnName("assigned_vehicle_id");
        builder.Property(x => x.VehicleRegistrationNumber).HasColumnName("vehicle_registration_number").HasMaxLength(15);
        builder.Property(x => x.VehicleBrand).HasColumnName("vehicle_brand").HasMaxLength(50);
        builder.Property(x => x.VehicleModel).HasColumnName("vehicle_model").HasMaxLength(50);
        builder.Property(x => x.VehicleColor).HasColumnName("vehicle_color").HasMaxLength(30);

        builder.Property(x => x.AssignedDriverId).HasColumnName("assigned_driver_id");
        builder.Property(x => x.DriverName).HasColumnName("driver_name").HasMaxLength(150);
        builder.Property(x => x.DriverPhone).HasColumnName("driver_phone").HasMaxLength(20);

        builder.Property(x => x.IdempotencyKey).HasColumnName("idempotency_key").HasMaxLength(100).IsRequired();
        builder.HasIndex(x => x.IdempotencyKey).IsUnique();

        builder.Property(x => x.TransactionId).HasColumnName("transaction_id").HasMaxLength(100).IsRequired();
        builder.Property(x => x.PaymentExpiresAt).HasColumnName("payment_expires_at").IsRequired();

        builder.Property(x => x.PaidAt).HasColumnName("paid_at");
        builder.Property(x => x.ConfirmedAt).HasColumnName("confirmed_at");
        builder.Property(x => x.CompletedAt).HasColumnName("completed_at");
        builder.Property(x => x.ExpiredAt).HasColumnName("expired_at");
        builder.Property(x => x.CancelledAt).HasColumnName("cancelled_at");
        builder.Property(x => x.CancellationReason).HasColumnName("cancellation_reason");
        builder.Property(x => x.OperatorNotes).HasColumnName("operator_notes");

        // Audit (from AuditableEntity / BaseDbContext)
        builder.Property(x => x.CreatedAt).HasColumnName("created_at");
        builder.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        builder.Property(x => x.IsActive).HasColumnName("is_active");
        builder.Property(x => x.Version).HasColumnName("version").IsConcurrencyToken();

        // Navigation
        builder.HasMany(x => x.Details)
            .WithOne(x => x.BookingOrder)
            .HasForeignKey(x => x.BookingOrderId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(x => x.SoftBookings)
            .WithOne(x => x.BookingOrder)
            .HasForeignKey(x => x.BookingOrderId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(x => x.Assignments)
            .WithOne(x => x.BookingOrder)
            .HasForeignKey(x => x.BookingOrderId);
    }
}
