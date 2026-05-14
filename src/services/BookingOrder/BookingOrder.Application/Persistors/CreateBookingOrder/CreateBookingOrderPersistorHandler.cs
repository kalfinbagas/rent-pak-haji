using BookingOrder.Application.Abstractions;
using BookingOrder.Domain.Enums;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using RentPakHaji.Common.Broker.Abstractions;
using RentPakHaji.Common.Contracts.Events.Booking;

namespace BookingOrder.Application.Persistors.CreateBookingOrder;

/// <summary>
/// Worker-side handler: writes the BookingOrder aggregate to the database.
///
/// Flow:
///   1. Idempotency check (IdempotencyKey already in DB? → skip)
///   2. Parse enums, generate booking code, calculate pricing
///   3. Persist BookingOrder + Details + VehicleSoftBooking
///   4. Publish SoftBookingCreatedEvent for the Vehicle service
/// </summary>
public sealed class CreateBookingOrderPersistorHandler
    : IRequestHandler<CreateBookingOrderPersistorCommand, Unit>
{
    private readonly IBookingOrderDbContext _db;
    private readonly IBookingCodeGenerator  _codeGenerator;
    private readonly IDateTimeProvider      _dateTime;
    private readonly IRabbitMqPublisher     _publisher;
    private readonly ILogger<CreateBookingOrderPersistorHandler> _logger;

    public CreateBookingOrderPersistorHandler(
        IBookingOrderDbContext db,
        IBookingCodeGenerator  codeGenerator,
        IDateTimeProvider      dateTime,
        IRabbitMqPublisher     publisher,
        ILogger<CreateBookingOrderPersistorHandler> logger)
    {
        _db            = db;
        _codeGenerator = codeGenerator;
        _dateTime      = dateTime;
        _publisher     = publisher;
        _logger        = logger;
    }

    public async Task<Unit> Handle(
        CreateBookingOrderPersistorCommand command,
        CancellationToken cancellationToken)
    {
        var msg = command.Message;

        // ── 1. Idempotency — skip if already processed ───────────
        bool alreadyExists = await _db.BookingOrders
            .AnyAsync(o => o.IdempotencyKey == msg.IdempotencyKey, cancellationToken);

        if (alreadyExists)
        {
            _logger.LogInformation(
                "BookingOrder with IdempotencyKey {Key} already exists — skipping (transactionId={TxId})",
                msg.IdempotencyKey, msg.TransactionId);
            return Unit.Value;
        }

        // ── 2. Parse enums ────────────────────────────────────────
        var serviceType = msg.ServiceType == "SELF_DRIVE"
            ? ServiceType.SelfDrive
            : ServiceType.WithDriver;

        var startExpType = msg.StartExpeditionType == "EXPEDITION"
            ? ExpeditionType.Expedition
            : ExpeditionType.SelfService;

        var endExpType = msg.EndExpeditionType == "EXPEDITION"
            ? ExpeditionType.Expedition
            : ExpeditionType.SelfService;

        // ── 3. Generate booking code & timing ─────────────────────
        var bookingCode      = await _codeGenerator.GenerateAsync(cancellationToken);
        var now              = _dateTime.UtcNow;
        var paymentExpiresAt = now.AddMinutes(15);

        // ── 4. Calculate pricing ───────────────────────────────────
        var subtotalRental     = msg.DailyRate * (msg.DurationDays ?? 1) * msg.NumberOfVehicles;
        var totalExpeditionFee = msg.StartExpeditionFee + msg.EndExpeditionFee;
        var subtotalAmount     = subtotalRental + totalExpeditionFee;
        var taxAmount          = 0m;    // TODO: integrate tax rules
        var voucherDiscount    = 0m;    // TODO: validate voucher code
        var totalAmount        = subtotalAmount + taxAmount - voucherDiscount;

        // ── 5. Create aggregate (use pre-assigned ID from API) ─────
        var order = Domain.Entities.BookingOrder.CreateWithId(
            id:                       msg.BookingOrderId,
            bookingCode:              bookingCode,
            customerId:               msg.CustomerId,
            customerName:             msg.CustomerName,
            customerPhone:            msg.CustomerPhone,
            customerEmail:            msg.CustomerEmail,
            serviceType:              serviceType,
            vehicleType:              msg.VehicleType,
            vehicleCategory:          msg.VehicleCategory,
            numberOfVehicles:         msg.NumberOfVehicles,
            startRentalAt:            msg.StartRentalAt,
            endRentalAt:              msg.EndRentalAt,
            durationDays:             msg.DurationDays,
            withDriverDurationHours:  msg.WithDriverDurationHours,
            isOutOfTown:              msg.IsOutOfTown,
            dailyRate:                msg.DailyRate,
            subtotalRental:           subtotalRental,
            subtotalAmount:           subtotalAmount,
            taxAmount:                taxAmount,
            totalAmount:              totalAmount,
            idempotencyKey:           msg.IdempotencyKey,
            transactionId:            msg.TransactionId,
            paymentExpiresAt:         paymentExpiresAt);

        await _db.BookingOrders.AddAsync(order, cancellationToken);

        // ── 6. START detail ────────────────────────────────────────
        var startDetail = Domain.Entities.BookingOrderDetail.Create(
            bookingOrderId:   order.Id,
            detailType:       "START",
            scheduledAt:      msg.StartRentalAt,
            timezone:         "Asia/Jakarta",
            expeditionType:   startExpType,
            poolLocationId:   msg.StartPoolLocationId,
            poolLocationName: msg.StartPoolLocationName,
            address:          msg.StartAddress,
            city:             msg.StartCity,
            district:         msg.StartDistrict,
            latitude:         msg.StartLatitude,
            longitude:        msg.StartLongitude,
            expeditionFee:    msg.StartExpeditionFee);

        await _db.BookingOrderDetails.AddAsync(startDetail, cancellationToken);

        // ── 7. END detail ──────────────────────────────────────────
        var endDetail = Domain.Entities.BookingOrderDetail.Create(
            bookingOrderId:   order.Id,
            detailType:       "END",
            scheduledAt:      msg.EndRentalAt,
            timezone:         "Asia/Jakarta",
            expeditionType:   endExpType,
            poolLocationId:   msg.EndPoolLocationId,
            poolLocationName: msg.EndPoolLocationName,
            address:          msg.EndAddress,
            city:             msg.EndCity,
            district:         msg.EndDistrict,
            latitude:         msg.EndLatitude,
            longitude:        msg.EndLongitude,
            expeditionFee:    msg.EndExpeditionFee);

        await _db.BookingOrderDetails.AddAsync(endDetail, cancellationToken);

        // ── 8. VehicleSoftBooking ──────────────────────────────────
        var softBooking = Domain.Entities.VehicleSoftBooking.Create(
            bookingOrderId:   order.Id,
            bookingCode:      bookingCode,
            vehicleType:      msg.VehicleType,
            poolLocationId:   msg.StartPoolLocationId,
            poolLocationName: msg.StartPoolLocationName,
            startRentalAt:    msg.StartRentalAt,
            endRentalAt:      msg.EndRentalAt,
            numberOfVehicles: msg.NumberOfVehicles,
            expiresAt:        paymentExpiresAt,
            transactionId:    msg.TransactionId,
            sequence:         1);

        await _db.VehicleSoftBookings.AddAsync(softBooking, cancellationToken);

        // ── 9. Persist (domain events → outbox via BaseDbContext) ──
        await _db.SaveChangesAsync(cancellationToken);

        // ── 10. Publish SoftBookingCreated for Vehicle service ─────
        await _publisher.PublishAsync(
            new SoftBookingCreatedEvent
            {
                TransactionId       = Guid.TryParse(msg.TransactionId, out var txGuid)
                                          ? txGuid : Guid.NewGuid(),
                BookingOrderId      = order.Id,
                SoftBookingId       = softBooking.Id,
                Sequence            = 1,
                VehicleCategoryName = msg.VehicleCategory ?? msg.VehicleType,
                NumberOfVehicles    = msg.NumberOfVehicles,
                PoolLocationId      = msg.StartPoolLocationId,
                PoolLocationName    = msg.StartPoolLocationName,
                StartDate           = msg.StartRentalAt.UtcDateTime,
                EndDate             = msg.EndRentalAt.UtcDateTime,
                ExpiredAt           = paymentExpiresAt.UtcDateTime
            },
            exchange:          "rpk.booking",
            routingKey:        "booking.soft-booking.created",
            cancellationToken: cancellationToken);

        _logger.LogInformation(
            "BookingOrder {Id} persisted (code={Code}, transactionId={TxId})",
            order.Id, bookingCode, msg.TransactionId);

        return Unit.Value;
    }
}
