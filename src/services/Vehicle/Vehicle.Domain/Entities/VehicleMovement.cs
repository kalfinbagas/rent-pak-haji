using RentPakHaji.Common.Domain.Primitives;
using Vehicle.Domain.Enums;

namespace Vehicle.Domain.Entities;

/// <summary>
/// Append-only audit trail — setiap perubahan status/lokasi kendaraan.
/// Never updated, only inserted.
/// </summary>
public sealed class VehicleMovement : BaseEntity
{
    public Guid               VehicleId       { get; private set; }
    public VehicleStatus?     PreviousStatus  { get; private set; }
    public VehicleStatus      NewStatus       { get; private set; }
    public Guid?              FromPoolId      { get; private set; }
    public string?            FromPoolName    { get; private set; }
    public Guid?              ToPoolId        { get; private set; }
    public string?            ToPoolName      { get; private set; }
    public Guid?              BookingId       { get; private set; }
    public string?            BookingCode     { get; private set; } // denorm
    public Guid               ChangedBy       { get; private set; }
    public string             ChangedByType   { get; private set; } = string.Empty; // SYSTEM|OPERATOR|CUSTOMER|SCHEDULER
    public MovementType       MovementType    { get; private set; }
    public MovementSource     MovementSource  { get; private set; }
    public string             Reason          { get; private set; } = string.Empty;
    public int?               OdometerAt      { get; private set; }
    public string?            Notes           { get; private set; }
    public string?            TransactionId   { get; private set; } // saga/event correlation ID
    public DateTimeOffset     CreatedAt       { get; private set; }

    private VehicleMovement() { }

    public static VehicleMovement Create(
        Guid vehicleId,
        VehicleStatus newStatus,
        Guid changedBy,
        string changedByType,
        MovementType movementType,
        MovementSource movementSource,
        string reason,
        VehicleStatus? previousStatus = null,
        Guid? fromPoolId = null,
        string? fromPoolName = null,
        Guid? toPoolId = null,
        string? toPoolName = null,
        Guid? bookingId = null,
        string? bookingCode = null,
        int? odometerAt = null,
        string? notes = null,
        string? transactionId = null)
    {
        return new VehicleMovement
        {
            Id             = Guid.NewGuid(),
            VehicleId      = vehicleId,
            PreviousStatus = previousStatus,
            NewStatus      = newStatus,
            ChangedBy      = changedBy,
            ChangedByType  = changedByType,
            MovementType   = movementType,
            MovementSource = movementSource,
            Reason         = reason,
            FromPoolId     = fromPoolId,
            FromPoolName   = fromPoolName,
            ToPoolId       = toPoolId,
            ToPoolName     = toPoolName,
            BookingId      = bookingId,
            BookingCode    = bookingCode,
            OdometerAt     = odometerAt,
            Notes          = notes,
            TransactionId  = transactionId,
            CreatedAt      = DateTimeOffset.UtcNow
        };
    }
}
