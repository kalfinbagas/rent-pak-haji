using RentPakHaji.Common.Domain.Primitives;
using Vehicle.Domain.Enums;

namespace Vehicle.Domain.Entities;

/// <summary>
/// Pre-dispatch checklist — cuci, inspeksi, BBM, NFC assignment, dokumen.
/// One preparation record per dispatch (vehicle_id + booking_id).
/// </summary>
public sealed class VehiclePreparation : AuditableEntity
{
    public Guid   VehicleId   { get; private set; }
    public Guid   BookingId   { get; private set; }
    public string BookingCode { get; private set; } = string.Empty;
    public Guid?  DispatchId  { get; private set; }
    public Guid   PicId       { get; private set; }
    public string PicName     { get; private set; } = string.Empty;

    // ── Checklist ─────────────────────────────────────────────────
    public PreparationStatus OverallStatus      { get; private set; } = PreparationStatus.Pending;

    public bool              IsWashed           { get; private set; }
    public DateTimeOffset?   WashCompletedAt    { get; private set; }

    public bool              IsInspected        { get; private set; }
    public DateTimeOffset?   InspectionCompletedAt { get; private set; }

    public bool              IsFueled           { get; private set; }
    public DateTimeOffset?   FuelCompletedAt    { get; private set; }

    public bool              IsNfcAssigned      { get; private set; }
    public DateTimeOffset?   NfcAssignedAt      { get; private set; }
    public string?           NfcCardUid         { get; private set; }

    public bool              IsDocumentChecked  { get; private set; }
    public DateTimeOffset?   DocumentCheckedAt  { get; private set; }

    // ── Timing ────────────────────────────────────────────────────
    public DateTimeOffset?   EstimatedReadyAt   { get; private set; }
    public DateTimeOffset?   ActualReadyAt      { get; private set; }

    public string?           Notes              { get; private set; }
    public string?           TransactionId      { get; private set; }

    private VehiclePreparation() { }

    public static VehiclePreparation Create(
        Guid vehicleId,
        Guid bookingId,
        string bookingCode,
        Guid picId,
        string picName,
        DateTimeOffset? estimatedReadyAt,
        string createdBy,
        string? transactionId = null)
    {
        return new VehiclePreparation
        {
            Id               = Guid.NewGuid(),
            VehicleId        = vehicleId,
            BookingId        = bookingId,
            BookingCode      = bookingCode,
            PicId            = picId,
            PicName          = picName,
            OverallStatus    = PreparationStatus.Pending,
            EstimatedReadyAt = estimatedReadyAt,
            TransactionId    = transactionId,
            CreatedBy        = createdBy,
            CreatedAt        = DateTime.UtcNow,
            IsActive         = true,
            Version          = 1
        };
    }

    public void CompleteWash()     { IsWashed    = true; WashCompletedAt    = DateTimeOffset.UtcNow; TryMarkComplete(); }
    public void CompleteInspection(){ IsInspected = true; InspectionCompletedAt = DateTimeOffset.UtcNow; TryMarkComplete(); }
    public void CompleteFuel()     { IsFueled    = true; FuelCompletedAt    = DateTimeOffset.UtcNow; TryMarkComplete(); }
    public void AssignNfc(string nfcCardUid) { IsNfcAssigned = true; NfcCardUid = nfcCardUid; NfcAssignedAt = DateTimeOffset.UtcNow; TryMarkComplete(); }
    public void CompleteDocCheck() { IsDocumentChecked = true; DocumentCheckedAt = DateTimeOffset.UtcNow; TryMarkComplete(); }

    private void TryMarkComplete()
    {
        OverallStatus = PreparationStatus.InProgress;
        if (IsWashed && IsInspected && IsFueled && IsNfcAssigned && IsDocumentChecked)
        {
            OverallStatus = PreparationStatus.Completed;
            ActualReadyAt = DateTimeOffset.UtcNow;
        }
        MarkUpdated();
    }
}
