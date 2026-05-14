using RentPakHaji.Common.Domain.Primitives;

namespace BookingOrder.Domain.Entities;

/// <summary>
/// Soft hold stok selama payment window (default 15 menit).
/// Direplikasi ke rpk_vehicle via event SoftBookingCreated/Released.
/// </summary>
public sealed class VehicleSoftBooking : BaseEntity
{
    public Guid BookingOrderId { get; private set; }
    public string BookingCode { get; private set; } = default!;

    // Spesifikasi stok yang di-hold
    public string VehicleType { get; private set; } = default!;
    public Guid PoolLocationId { get; private set; }
    public string PoolLocationName { get; private set; } = default!;

    public DateTimeOffset StartRentalAt { get; private set; }
    public DateTimeOffset EndRentalAt { get; private set; }

    public int NumberOfVehicles { get; private set; } = 1;

    public DateTimeOffset ExpiresAt { get; private set; }

    public SoftBookingStatus Status { get; private set; } = SoftBookingStatus.Active;

    public int Sequence { get; private set; } = 1;

    public string TransactionId { get; private set; } = default!;

    public DateTimeOffset CreatedAt { get; private set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; private set; } = DateTimeOffset.UtcNow;

    // ─── Navigation ────────────────────────────────────────────
    public BookingOrder BookingOrder { get; private set; } = default!;

    private VehicleSoftBooking() { }

    public static VehicleSoftBooking Create(
        Guid bookingOrderId,
        string bookingCode,
        string vehicleType,
        Guid poolLocationId,
        string poolLocationName,
        DateTimeOffset startRentalAt,
        DateTimeOffset endRentalAt,
        int numberOfVehicles,
        DateTimeOffset expiresAt,
        string transactionId,
        int sequence = 1)
    {
        return new VehicleSoftBooking
        {
            BookingOrderId = bookingOrderId,
            BookingCode = bookingCode,
            VehicleType = vehicleType,
            PoolLocationId = poolLocationId,
            PoolLocationName = poolLocationName,
            StartRentalAt = startRentalAt,
            EndRentalAt = endRentalAt,
            NumberOfVehicles = numberOfVehicles,
            ExpiresAt = expiresAt,
            TransactionId = transactionId,
            Sequence = sequence,
        };
    }

    public void Release()
    {
        Status = SoftBookingStatus.Released;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void Expire()
    {
        Status = SoftBookingStatus.Expired;
        UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void Convert()
    {
        Status = SoftBookingStatus.Converted;
        UpdatedAt = DateTimeOffset.UtcNow;
    }
}
