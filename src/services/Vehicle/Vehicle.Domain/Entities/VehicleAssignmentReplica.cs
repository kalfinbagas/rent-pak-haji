using RentPakHaji.Common.Domain.Primitives;
using Vehicle.Domain.Enums;

namespace Vehicle.Domain.Entities;

/// <summary>
/// Replicated copy of BookingOrder's VehicleAssignment — synced via VehicleAssignmentCreated event.
/// Vehicle service uses this to:
///   1. UPDATE master_vehicle SET status = READY
///   2. Map NFC card to vehicle
///   3. Dashboard: show which units are dispatched
/// INSERT is idempotent (ON CONFLICT DO NOTHING on PK = source ID).
/// </summary>
public sealed class VehicleAssignmentReplica : BaseEntity
{
    public string BookingCode     { get; private set; } = string.Empty;

    // FK to MasterVehicle (same DB — only FK here)
    public Guid   VehicleId       { get; private set; }
    public string LicensePlate    { get; private set; } = string.Empty;
    public string VehicleType     { get; private set; } = string.Empty;
    public string? VehicleCategory { get; private set; }
    public string? Brand           { get; private set; }
    public string? Model           { get; private set; }

    // Driver snapshot (ref only, no FK)
    public Guid?  DriverId        { get; private set; }
    public string? DriverName     { get; private set; }

    // NFC mapping
    public string? NfcCardUid     { get; private set; }

    // Pool dispatch
    public Guid   PoolLocationId   { get; private set; }
    public string PoolLocationName { get; private set; } = string.Empty;

    public DateTimeOffset AssignedAt { get; private set; }

    public AssignmentReplicaStatus Status          { get; private set; } = AssignmentReplicaStatus.Pending;
    public short                   AssignmentStatus { get; private set; } = 0; // 0=ASSIGNED,1=RELEASED,2=REJECTED

    // Replication metadata
    public DateTimeOffset SyncedAt      { get; private set; }
    public int            Sequence      { get; private set; }
    public string         TransactionId { get; private set; } = string.Empty;

    // Navigation
    public MasterVehicle? Vehicle { get; private set; }

    private VehicleAssignmentReplica() { }

    public static VehicleAssignmentReplica CreateFromEvent(
        Guid id,
        string bookingCode,
        Guid vehicleId,
        string licensePlate,
        string vehicleType,
        string? vehicleCategory,
        string? brand,
        string? model,
        Guid poolLocationId,
        string poolLocationName,
        DateTimeOffset assignedAt,
        int sequence,
        string transactionId,
        Guid? driverId = null,
        string? driverName = null)
    {
        return new VehicleAssignmentReplica
        {
            Id               = id,
            BookingCode      = bookingCode,
            VehicleId        = vehicleId,
            LicensePlate     = licensePlate,
            VehicleType      = vehicleType,
            VehicleCategory  = vehicleCategory,
            Brand            = brand,
            Model            = model,
            DriverId         = driverId,
            DriverName       = driverName,
            PoolLocationId   = poolLocationId,
            PoolLocationName = poolLocationName,
            AssignedAt       = assignedAt,
            Status           = AssignmentReplicaStatus.Pending,
            AssignmentStatus = 0,
            SyncedAt         = DateTimeOffset.UtcNow,
            Sequence         = sequence,
            TransactionId    = transactionId
        };
    }

    public void SetNfcCard(string nfcCardUid) => NfcCardUid = nfcCardUid;
    public void MarkDispatched() => Status = AssignmentReplicaStatus.Dispatched;
    public void MarkReturned()   { Status = AssignmentReplicaStatus.Returned;  AssignmentStatus = 1; }
    public void Cancel()         { Status = AssignmentReplicaStatus.Cancelled; AssignmentStatus = 2; }
}
