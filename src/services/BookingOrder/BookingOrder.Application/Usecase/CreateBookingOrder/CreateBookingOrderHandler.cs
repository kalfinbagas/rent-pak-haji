using RentPakHaji.Common.Application.Abstractions;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Broker.Abstractions;

namespace BookingOrder.Application.Usecase.CreateBookingOrder;

/// <summary>
/// API-side handler: validate → publish to broker → return 202 Accepted.
///
/// No DB writes occur here.  Actual persistence is handled asynchronously by
/// <c>CreateBookingOrderConsumer</c> in the Worker project, which dispatches to
/// <c>CreateBookingOrderPersistorHandler</c> via MediatR.
///
/// <see cref="BookingOrderId"/> is pre-assigned here so the client can poll
/// GET /api/booking-orders/{bookingOrderId} without waiting for the Worker to finish.
/// </summary>
public sealed class CreateBookingOrderHandler
    : ICommandHandler<CreateBookingOrderCommand, Result<CreateBookingOrderResponse>>
{
    private readonly IRabbitMqPublisher _publisher;

    public CreateBookingOrderHandler(IRabbitMqPublisher publisher)
    {
        _publisher = publisher;
    }

    public async Task<Result<CreateBookingOrderResponse>> Handle(
        CreateBookingOrderCommand cmd,
        CancellationToken cancellationToken)
    {
        // Pre-assign IDs — embedded in message so Worker uses them as PK
        var bookingOrderId = Guid.NewGuid();
        var transactionId  = Guid.NewGuid().ToString("N");

        var message = new CreateBookingOrderMessage
        {
            BookingOrderId         = bookingOrderId,
            TransactionId          = transactionId,
            CustomerId             = cmd.CustomerId,
            CustomerName           = cmd.CustomerName,
            CustomerPhone          = cmd.CustomerPhone,
            CustomerEmail          = cmd.CustomerEmail,
            ServiceType            = cmd.ServiceType,
            VehicleType            = cmd.VehicleType,
            VehicleCategory        = cmd.VehicleCategory,
            NumberOfVehicles       = cmd.NumberOfVehicles,
            StartRentalAt          = cmd.StartRentalAt,
            EndRentalAt            = cmd.EndRentalAt,
            DurationDays           = cmd.DurationDays,
            WithDriverDurationHours = cmd.WithDriverDurationHours,
            IsOutOfTown            = cmd.IsOutOfTown,
            StartExpeditionType    = cmd.StartExpeditionType,
            StartPoolLocationId    = cmd.StartPoolLocationId,
            StartPoolLocationName  = cmd.StartPoolLocationName,
            StartAddress           = cmd.StartAddress,
            StartCity              = cmd.StartCity,
            StartDistrict          = cmd.StartDistrict,
            StartLatitude          = cmd.StartLatitude,
            StartLongitude         = cmd.StartLongitude,
            StartExpeditionFee     = cmd.StartExpeditionFee,
            EndExpeditionType      = cmd.EndExpeditionType,
            EndPoolLocationId      = cmd.EndPoolLocationId,
            EndPoolLocationName    = cmd.EndPoolLocationName,
            EndAddress             = cmd.EndAddress,
            EndCity                = cmd.EndCity,
            EndDistrict            = cmd.EndDistrict,
            EndLatitude            = cmd.EndLatitude,
            EndLongitude           = cmd.EndLongitude,
            EndExpeditionFee       = cmd.EndExpeditionFee,
            DailyRate              = cmd.DailyRate,
            VoucherCode            = cmd.VoucherCode,
            IdempotencyKey         = cmd.IdempotencyKey
        };

        await _publisher.PublishAsync(
            message,
            exchange:          "rpk.bookingorder",
            routingKey:        "bookingorder.order.create",
            cancellationToken: cancellationToken);

        return Result.Success(new CreateBookingOrderResponse(bookingOrderId, transactionId));
    }
}
