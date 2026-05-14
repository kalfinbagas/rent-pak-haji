using RentPakHaji.Common.Application.Abstractions;
using RentPakHaji.Common.Application;

namespace BookingOrder.Application.Usecase.CreateBookingOrder;

/// <summary>
/// API-side command: validated then forwarded to RabbitMQ.
/// No DB writes occur here — the actual persistence is handled
/// by <see cref="CreateBookingOrderPersistorHandler"/> in the Worker.
/// </summary>
public sealed record CreateBookingOrderCommand(
    Guid CustomerId,
    string CustomerName,
    string CustomerPhone,
    string? CustomerEmail,

    string ServiceType,             // SELF_DRIVE | WITH_DRIVER
    string VehicleType,             // CAR | MOTORCYCLE
    string? VehicleCategory,
    int NumberOfVehicles,

    DateTimeOffset StartRentalAt,
    DateTimeOffset EndRentalAt,
    int? DurationDays,
    int? WithDriverDurationHours,
    bool IsOutOfTown,

    // START detail
    string StartExpeditionType,     // SELF_SERVICE | EXPEDITION
    Guid StartPoolLocationId,
    string StartPoolLocationName,
    string? StartAddress,
    string? StartCity,
    string? StartDistrict,
    decimal? StartLatitude,
    decimal? StartLongitude,
    decimal StartExpeditionFee,

    // END detail
    string EndExpeditionType,
    Guid EndPoolLocationId,
    string EndPoolLocationName,
    string? EndAddress,
    string? EndCity,
    string? EndDistrict,
    decimal? EndLatitude,
    decimal? EndLongitude,
    decimal EndExpeditionFee,

    // Pricing
    decimal DailyRate,
    string? VoucherCode,

    // Idempotency
    string IdempotencyKey
) : ICommand<Result<CreateBookingOrderResponse>>;
