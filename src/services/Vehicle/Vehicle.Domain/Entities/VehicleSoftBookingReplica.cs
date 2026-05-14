using RentPakHaji.Common.Domain.Primitives;
using Vehicle.Domain.Enums;

namespace Vehicle.Domain.Entities;

/// <summary>
/// Replicated copy of BookingOrder's VehicleSoftBooking — synced via SoftBookingCreated event.
/// Used by Inventory logic to calculate available stock without cross-DB joins.
/// INSERT is idempotent (ON CONFLICT DO NOTHING on PK = source ID).
/// </summary>
public sealed class VehicleSoftBookingReplica : BaseEntity
{
    public string BookingCode       { get; private set; } = string.Empty;
    public Guid   BookingDetailId   { get; private set; }

    // Stock filter fields
    public string VehicleType       { get; private set; } = string.Empty;
    public Guid   PoolLocationId    { get; private set; }
    public string PoolLocationName  { get; private set; } = string.Empty;

    public DateTimeOffset StartRentalAt { get; private set; }
    public DateTimeOffset EndRentalAt   { get; private set; }
    public DateTimeOffset ExpiresAt     { get; private set; }

    public SoftBookingReplicaStatus Status { get; private set; } = SoftBookingReplicaStatus.Active;
    public int  NumberOfVehicles    { get; private set; } = 1;

    // Replication metadata
    public DateTimeOffset SyncedAt      { get; private set; }
    public int            Sequence      { get; private set; }
    public string         TransactionId { get; private set; } = string.Empty;

    private VehicleSoftBookingReplica() { }

    /// <summary>Called when SoftBookingCreated event is consumed.</summary>
    public static VehicleSoftBookingReplica CreateFromEvent(
        Guid id,
        string bookingCode,
        Guid bookingDetailId,
        string vehicleType,
        Guid poolLocationId,
        string poolLocationName,
        DateTimeOffset startRentalAt,
        DateTimeOffset endRentalAt,
        DateTimeOffset expiresAt,
        int numberOfVehicles,
        int sequence,
        string transactionId)
    {
        return new VehicleSoftBookingReplica
        {
            Id               = id,   // same ID as source — guarantees idempotency
            BookingCode      = bookingCode,
            BookingDetailId  = bookingDetailId,
            VehicleType      = vehicleType,
            PoolLocationId   = poolLocationId,
            PoolLocationName = poolLocationName,
            StartRentalAt    = startRentalAt,
            EndRentalAt      = endRentalAt,
            ExpiresAt        = expiresAt,
            Status           = SoftBookingReplicaStatus.Active,
            NumberOfVehicles = numberOfVehicles,
            SyncedAt         = DateTimeOffset.UtcNow,
            Sequence         = sequence,
            TransactionId    = transactionId
        };
    }

    public void Release() => Status = SoftBookingReplicaStatus.Released;
    public void Expire()  => Status = SoftBookingReplicaStatus.Expired;
    public void Convert() => Status = SoftBookingReplicaStatus.Converted;
}
