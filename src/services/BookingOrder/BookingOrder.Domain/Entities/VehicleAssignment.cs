using RentPakHaji.Common.Domain.Primitives;

namespace BookingOrder.Domain.Entities;

/// <summary>
/// Assignment kendaraan + driver + NFC ke booking saat dispatch.
/// Direplikasi ke rpk_vehicle via VehicleAssigned event.
/// Sequence bertambah setiap kendaraan diganti — history tetap terjaga.
/// </summary>
public sealed class VehicleAssignment : BaseEntity
{
    public Guid BookingOrderId { get; private set; }
    public Guid BookingDetailId { get; private set; }
    public string BookingCode { get; private set; } = default!;

    // ─── Vehicle snapshot ──────────────────────────────────────
    public Guid VehicleId { get; private set; }
    public string LicensePlate { get; private set; } = default!;
    public string VehicleType { get; private set; } = default!;
    public string? VehicleCategory { get; private set; }
    public string Brand { get; private set; } = default!;
    public string Model { get; private set; } = default!;
    public int? VehicleYear { get; private set; }
    public string? Color { get; private set; }

    // ─── Driver snapshot (optional — with_driver only) ─────────
    public Guid? DriverId { get; private set; }
    public string? DriverName { get; private set; }
    public string? DriverPhone { get; private set; }

    // ─── NFC ───────────────────────────────────────────────────
    public string? NfcCardUid { get; private set; }

    // ─── Pool ──────────────────────────────────────────────────
    public Guid DispatchPoolId { get; private set; }
    public string DispatchPoolName { get; private set; } = default!;
    public Guid? ReturnPoolId { get; private set; }
    public string? ReturnPoolName { get; private set; }

    // ─── Timing ────────────────────────────────────────────────
    public DateTimeOffset AssignedAt { get; private set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? DispatchedAt { get; private set; }
    public DateTimeOffset? ReturnedAt { get; private set; }

    // ─── Status ────────────────────────────────────────────────
    public AssignmentStatusMain Status { get; private set; } = AssignmentStatusMain.Pending;

    /// <summary>0=ASSIGNED, 1=RELEASED, 2=REJECTED</summary>
    public short AssignmentStatus { get; private set; } = 0;

    /// <summary>Bertambah setiap kendaraan diganti — history terjaga.</summary>
    public int Sequence { get; private set; } = 1;

    public short? ReleaseReasonType { get; private set; }
    public string? ReleaseReasonNote { get; private set; }
    public DateTimeOffset? ReleasedAt { get; private set; }
    public string? ReleasedBy { get; private set; }

    public string TransactionId { get; private set; } = default!;

    public DateTimeOffset CreatedAt { get; private set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; private set; } = DateTimeOffset.UtcNow;

    // ─── Navigation ────────────────────────────────────────────
    public BookingOrder BookingOrder { get; private set; } = default!;
    public BookingOrderDetail BookingDetail { get; private set; } = default!;

    private VehicleAssignment() { }

    public static VehicleAssignment Create(
        Guid bookingOrderId,
        Guid bookingDetailId,
        string bookingCode,
        Guid vehicleId,
        string licensePlate,
        string vehicleType,
        string? vehicleCategory,
        string brand,
        string model,
        int? vehicleYear,
        string? color,
        Guid? driverId,
        string? driverName,
        string? driverPhone,
        string? nfcCardUid,
        Guid dispatchPoolId,
        string dispatchPoolName,
        Guid? returnPoolId,
        string? returnPoolName,
        string transactionId,
        int sequence = 1)
    {
        return new VehicleAssignment
        {
            BookingOrderId = bookingOrderId,
            BookingDetailId = bookingDetailId,
            BookingCode = bookingCode,
            VehicleId = vehicleId,
            LicensePlate = licensePlate,
            VehicleType = vehicleType,
            VehicleCategory = vehicleCategory,
            Brand = brand,
            Model = model,
            VehicleYear = vehicleYear,
            Color = color,
            DriverId = driverId,
            DriverName = driverName,
            DriverPhone = driverPhone,
            NfcCardUid = nfcCardUid,
            DispatchPoolId = dispatchPoolId,
            DispatchPoolName = dispatchPoolName,
            ReturnPoolId = returnPoolId,
            ReturnPoolName = returnPoolName,
            TransactionId = transactionId,
            Sequence = sequence,
        };
    }

    public void MarkDispatched(DateTimeOffset dispatchedAt)
    {
        Status = AssignmentStatusMain.Dispatched;
        DispatchedAt = dispatchedAt;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void MarkReturned(DateTimeOffset returnedAt)
    {
        Status = AssignmentStatusMain.Returned;
        ReturnedAt = returnedAt;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void Release(short reasonType, string? reasonNote, string releasedBy)
    {
        AssignmentStatus = 1;
        Status = AssignmentStatusMain.Cancelled;
        ReleaseReasonType = reasonType;
        ReleaseReasonNote = reasonNote;
        ReleasedAt = DateTimeOffset.UtcNow;
        ReleasedBy = releasedBy;
        UpdatedAt = DateTimeOffset.UtcNow;
    }
}
