using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Vehicle.Domain.Entities;

namespace Vehicle.Infrastructure.Persistence.Configurations;

internal sealed class VehicleMovementConfiguration : IEntityTypeConfiguration<VehicleMovement>
{
    public void Configure(EntityTypeBuilder<VehicleMovement> b)
    {
        b.ToTable("vehicle_movement");
        b.HasKey(x => x.Id);

        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.VehicleId).HasColumnName("vehicle_id");
        b.Property(x => x.PreviousStatus).HasColumnName("previous_status").HasConversion<string?>().IsRequired(false);
        b.Property(x => x.NewStatus).HasColumnName("new_status").HasConversion<string>().IsRequired();
        b.Property(x => x.FromPoolId).HasColumnName("from_pool_id");
        b.Property(x => x.FromPoolName).HasColumnName("from_pool_name").HasMaxLength(150);
        b.Property(x => x.ToPoolId).HasColumnName("to_pool_id");
        b.Property(x => x.ToPoolName).HasColumnName("to_pool_name").HasMaxLength(150);
        b.Property(x => x.BookingId).HasColumnName("booking_id");
        b.Property(x => x.BookingCode).HasColumnName("booking_code").HasMaxLength(20);
        b.Property(x => x.ChangedBy).HasColumnName("changed_by");
        b.Property(x => x.ChangedByType).HasColumnName("changed_by_type").HasMaxLength(20);
        b.Property(x => x.MovementType).HasColumnName("movement_type").HasConversion<string>();
        b.Property(x => x.MovementSource).HasColumnName("movement_source").HasConversion<string>();
        b.Property(x => x.Reason).HasColumnName("reason").HasMaxLength(200);
        b.Property(x => x.OdometerAt).HasColumnName("odometer_at");
        b.Property(x => x.Notes).HasColumnName("notes");
        b.Property(x => x.TransactionId).HasColumnName("transaction_id").HasMaxLength(100);
        b.Property(x => x.CreatedAt).HasColumnName("created_at");

        b.HasIndex(x => x.VehicleId).HasDatabaseName("idx_vm_vehicle");
        b.HasIndex(x => x.BookingId).HasDatabaseName("idx_vm_booking");

        // Ignore in-memory domain events list
        b.Ignore(x => x.DomainEvents);
    }
}
