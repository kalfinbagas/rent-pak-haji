using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Vehicle.Domain.Entities;

namespace Vehicle.Infrastructure.Persistence.Configurations;

internal sealed class VehiclePreparationConfiguration : IEntityTypeConfiguration<VehiclePreparation>
{
    public void Configure(EntityTypeBuilder<VehiclePreparation> b)
    {
        b.ToTable("vehicle_preparation");
        b.HasKey(x => x.Id);

        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.VehicleId).HasColumnName("vehicle_id");
        b.Property(x => x.BookingId).HasColumnName("booking_id");
        b.Property(x => x.BookingCode).HasColumnName("booking_code").HasMaxLength(20);
        b.Property(x => x.DispatchId).HasColumnName("dispatch_id");
        b.Property(x => x.PicId).HasColumnName("pic_id");
        b.Property(x => x.PicName).HasColumnName("pic_name").HasMaxLength(150);

        b.Property(x => x.OverallStatus).HasColumnName("overall_status").HasConversion<string>();

        b.Property(x => x.IsWashed).HasColumnName("is_washed");
        b.Property(x => x.WashCompletedAt).HasColumnName("wash_completed_at");
        b.Property(x => x.IsInspected).HasColumnName("is_inspected");
        b.Property(x => x.InspectionCompletedAt).HasColumnName("inspection_completed_at");
        b.Property(x => x.IsFueled).HasColumnName("is_fueled");
        b.Property(x => x.FuelCompletedAt).HasColumnName("fuel_completed_at");
        b.Property(x => x.IsNfcAssigned).HasColumnName("is_nfc_assigned");
        b.Property(x => x.NfcAssignedAt).HasColumnName("nfc_assigned_at");
        b.Property(x => x.NfcCardUid).HasColumnName("nfc_card_uid").HasMaxLength(50);
        b.Property(x => x.IsDocumentChecked).HasColumnName("is_document_checked");
        b.Property(x => x.DocumentCheckedAt).HasColumnName("document_checked_at");

        b.Property(x => x.EstimatedReadyAt).HasColumnName("estimated_ready_at");
        b.Property(x => x.ActualReadyAt).HasColumnName("actual_ready_at");
        b.Property(x => x.Notes).HasColumnName("notes");
        b.Property(x => x.TransactionId).HasColumnName("transaction_id").HasMaxLength(100);

        b.Property(x => x.IsActive).HasColumnName("is_active");
        b.Property(x => x.Version).HasColumnName("version").IsConcurrencyToken();
        b.Property(x => x.CreatedBy).HasColumnName("created_by").HasMaxLength(50);
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.Property(x => x.UpdatedBy).HasColumnName("modified_by").HasMaxLength(50);
        b.Property(x => x.UpdatedAt).HasColumnName("modified_at");

        b.HasIndex(x => x.VehicleId).HasDatabaseName("idx_vp_vehicle");
        b.HasIndex(x => x.BookingId).HasDatabaseName("idx_vp_booking");

        b.Ignore(x => x.DomainEvents);
    }
}
