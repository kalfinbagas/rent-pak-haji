using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RentPakHaji.Common.Broker.Abstractions;
using RentPakHaji.Common.Contracts.Events.Booking;
using Vehicle.Application.Abstractions;

namespace Vehicle.Application.Consumers;

/// <summary>
/// Consumes SoftBookingReleased from queue "vehicle.soft-booking.released".
/// Updates the replicated record status to Released or Converted.
///
/// Uses IServiceScopeFactory to resolve scoped IVehicleDbContext per message.
/// </summary>
public sealed class ReleaseSoftBookingConsumer : RabbitMqConsumerBase<SoftBookingReleasedEvent>
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IConnectionFactory _connectionFactory;
    private readonly ILogger<ReleaseSoftBookingConsumer> _logger;

    public ReleaseSoftBookingConsumer(
        IServiceScopeFactory scopeFactory,
        IConnectionFactory connectionFactory,
        ILogger<ReleaseSoftBookingConsumer> logger)
        : base("vehicle.soft-booking.released", logger)
    {
        _scopeFactory      = scopeFactory;
        _connectionFactory = connectionFactory;
        _logger            = logger;
    }

    protected override IConnectionFactory ConnectionFactory => _connectionFactory;

    protected override async Task HandleAsync(SoftBookingReleasedEvent evt, CancellationToken ct)
    {
        await using var scope = _scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<IVehicleDbContext>();

        var replica = await db.VehicleSoftBookings
            .FirstOrDefaultAsync(x => x.Id == evt.SoftBookingId, ct);

        if (replica is null)
        {
            _logger.LogWarning(
                "SoftBooking {Id} not found in replica — may arrive out-of-order (transactionId={TxId})",
                evt.SoftBookingId, evt.TransactionId);
            return;
        }

        if (evt.Reason == "PAYMENT_SUCCESS")
            replica.Convert();
        else
            replica.Release();

        await db.SaveChangesAsync(ct);
    }
}
