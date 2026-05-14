namespace BookingOrder.Application.Usecase.CreateBookingOrder;

/// <summary>
/// Message payload published to RabbitMQ by the API handler.
/// Exchange  : rpk.bookingorder
/// RoutingKey: bookingorder.order.create
/// Queue     : bookingorder.order.create
///
/// <see cref="BookingOrderId"/> is pre-assigned by the API so the client can
/// poll GET /api/booking-orders/{id} immediately after receiving the 202 response.
/// </summary>
public sealed record CreateBookingOrderMessage
{
    // Pre-assigned by the API handler — used as DB primary key
    public Guid   BookingOrderId  { get; init; }
    public string TransactionId   { get; init; } = string.Empty;

    // Customer
    public Guid    CustomerId     { get; init; }
    public string  CustomerName   { get; init; } = string.Empty;
    public string  CustomerPhone  { get; init; } = string.Empty;
    public string? CustomerEmail  { get; init; }

    // Order
    public string  ServiceType           { get; init; } = string.Empty;
    public string  VehicleType           { get; init; } = string.Empty;
    public string? VehicleCategory       { get; init; }
    public int     NumberOfVehicles      { get; init; }
    public DateTimeOffset StartRentalAt  { get; init; }
    public DateTimeOffset EndRentalAt    { get; init; }
    public int?  DurationDays            { get; init; }
    public int?  WithDriverDurationHours { get; init; }
    public bool  IsOutOfTown             { get; init; }

    // START detail
    public string  StartExpeditionType   { get; init; } = string.Empty;
    public Guid    StartPoolLocationId   { get; init; }
    public string  StartPoolLocationName { get; init; } = string.Empty;
    public string? StartAddress          { get; init; }
    public string? StartCity             { get; init; }
    public string? StartDistrict         { get; init; }
    public decimal? StartLatitude        { get; init; }
    public decimal? StartLongitude       { get; init; }
    public decimal StartExpeditionFee    { get; init; }

    // END detail
    public string  EndExpeditionType     { get; init; } = string.Empty;
    public Guid    EndPoolLocationId     { get; init; }
    public string  EndPoolLocationName   { get; init; } = string.Empty;
    public string? EndAddress            { get; init; }
    public string? EndCity               { get; init; }
    public string? EndDistrict           { get; init; }
    public decimal? EndLatitude          { get; init; }
    public decimal? EndLongitude         { get; init; }
    public decimal EndExpeditionFee      { get; init; }

    // Pricing
    public decimal DailyRate             { get; init; }
    public string? VoucherCode           { get; init; }

    // Idempotency
    public string IdempotencyKey         { get; init; } = string.Empty;
}
