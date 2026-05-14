using RentPakHaji.Common.Domain.Primitives;

namespace BookingOrder.Domain.Entities;

/// <summary>
/// 2 records per order: START (kapan/dimana diserahkan) dan END (kapan/dimana dikembalikan).
/// </summary>
public sealed class BookingOrderDetail : BaseEntity
{
    public Guid BookingOrderId { get; private set; }

    /// <summary>START atau END</summary>
    public string DetailType { get; private set; } = default!;

    public DateTimeOffset ScheduledAt { get; private set; }
    public string Timezone { get; private set; } = "Asia/Jakarta";

    public ExpeditionType ExpeditionType { get; private set; } = ExpeditionType.SelfService;

    // Pool selalu diisi — pool asal (START) atau tujuan (END)
    public Guid PoolLocationId { get; private set; }
    public string PoolLocationName { get; private set; } = default!;

    // Diisi hanya jika ExpeditionType = Expedition
    public string? Address { get; private set; }
    public string? City { get; private set; }
    public string? District { get; private set; }
    public decimal? Latitude { get; private set; }
    public decimal? Longitude { get; private set; }

    public decimal ExpeditionFee { get; private set; } = 0;

    public DateTimeOffset CreatedAt { get; private set; } = DateTimeOffset.UtcNow;

    // ─── Navigation ────────────────────────────────────────────
    public BookingOrder BookingOrder { get; private set; } = default!;

    private BookingOrderDetail() { }

    public static BookingOrderDetail Create(
        Guid bookingOrderId,
        string detailType,
        DateTimeOffset scheduledAt,
        string timezone,
        ExpeditionType expeditionType,
        Guid poolLocationId,
        string poolLocationName,
        string? address = null,
        string? city = null,
        string? district = null,
        decimal? latitude = null,
        decimal? longitude = null,
        decimal expeditionFee = 0)
    {
        return new BookingOrderDetail
        {
            BookingOrderId = bookingOrderId,
            DetailType = detailType,
            ScheduledAt = scheduledAt,
            Timezone = timezone,
            ExpeditionType = expeditionType,
            PoolLocationId = poolLocationId,
            PoolLocationName = poolLocationName,
            Address = address,
            City = city,
            District = district,
            Latitude = latitude,
            Longitude = longitude,
            ExpeditionFee = expeditionFee,
        };
    }
}
