using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RentPakHaji.Common.Broker.Abstractions;
using RentPakHaji.Common.Contracts.Events.Booking;
using Vehicle.Application.Abstractions;
using Vehicle.Domain.Entities;

namespace Vehicle.Application.Consumers;

/// <summary>
/// Consumes SoftBookingCreated from queue "vehicle.soft-booking.created".
/// Replicates the soft-booking into rpk_vehicle.vehicle_soft_booking.
/// INSERT is idempotent — skipped if ID already exists.
///
/// Uses IServiceScopeFactory to resolve scoped IVehicleDbContext per message
/// (BackgroundService is singleton; DbContext is scoped).
/// </summary>
public sealed class ReplicateSoftBookingConsumer : RabbitMqConsumerBase<SoftBookingCreatedEvent>
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IConnectionFactory _connectionFactory;

    public ReplicateSoftBookingConsumer(
        IServiceScopeFactory scopeFactory,
        IConnectionFactory connectionFactory,
        ILogger<ReplicateSoftBookingConsumer> logger)
        : base("vehicle.soft-booking.created", logger)
    {
        _scopeFactory      = scopeFactory;
        _connectionFactory = connectionFactory;
    }

    protected override IConnectionFactory ConnectionFactory => _connectionFactory;

    protected override async Task HandleAsync(SoftBookingCreatedEvent evt, CancellationToken ct)
    {
        await using var scope = _scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<IVehicleDbContext>();

        bool exists = await db.VehicleSoftBookings
            .AnyAsync(x => x.Id == evt.SoftBookingId, ct);

        if (exists) return; // idempotent

        var replica = VehicleSoftBookingReplica.CreateFromEvent(
            id:              evt.SoftBookingId,
            bookingCode:     evt.BookingOrderId.ToString(),
            bookingDetailId: Guid.Empty,               // TODO: add BookingDetailId to event contract
            vehicleType:     evt.VehicleCategoryName,
            poolLocationId:  evt.PoolLocationId,
            poolLocationName:evt.PoolLocationName,
            startRentalAt:   new DateTimeOffset(evt.StartDate, TimeSpan.Zero),
            endRentalAt:     new DateTimeOffset(evt.EndDate,   TimeSpan.Zero),
            expiresAt:       new DateTimeOffset(evt.ExpiredAt, TimeSpan.Zero),
            numberOfVehicles:evt.NumberOfVehicles,
            sequence:        evt.Sequence,
            transactionId:   evt.TransactionId.ToString());

        await db.VehicleSoftBookings.AddAsync(replica, ct);
        await db.SaveChangesAsync(ct);
    }
}
