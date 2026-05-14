using BookingOrder.Application.Persistors.CreateBookingOrder;
using BookingOrder.Application.Usecase.CreateBookingOrder;
using BookingOrder.Worker.Workers;
using MediatR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using System.Text.Json;

namespace BookingOrder.Worker.Consumers;

/// <summary>
/// Subscribes to queue <c>bookingorder.order.create</c>.
/// On each message, dispatches <see cref="CreateBookingOrderPersistorCommand"/> via MediatR.
///
/// The consumer itself is thin — all business logic lives in
/// <see cref="CreateBookingOrderPersistorHandler"/>.
///
/// Lifecycle managed by <see cref="MainWorker"/> via <see cref="IConsumerService"/>.
/// </summary>
public sealed class CreateBookingOrderConsumer : IConsumerService
{
    private const string QueueName = "bookingorder.order.create";

    private readonly IConnectionFactory         _connectionFactory;
    private readonly IServiceScopeFactory       _scopeFactory;
    private readonly ILogger<CreateBookingOrderConsumer> _logger;

    private IConnection? _connection;
    private IChannel?    _channel;

    public string Name => nameof(CreateBookingOrderConsumer);

    public CreateBookingOrderConsumer(
        IConnectionFactory         connectionFactory,
        IServiceScopeFactory       scopeFactory,
        ILogger<CreateBookingOrderConsumer> logger)
    {
        _connectionFactory = connectionFactory;
        _scopeFactory      = scopeFactory;
        _logger            = logger;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        _connection = await _connectionFactory.CreateConnectionAsync(cancellationToken);
        _channel    = await _connection.CreateChannelAsync(cancellationToken: cancellationToken);

        // Declare queue + DLX binding
        await _channel.QueueDeclareAsync(
            queue:      QueueName,
            durable:    true,
            exclusive:  false,
            autoDelete: false,
            arguments: new Dictionary<string, object?>
            {
                ["x-dead-letter-exchange"]    = "",
                ["x-dead-letter-routing-key"] = $"{QueueName}.dlq"
            },
            cancellationToken: cancellationToken);

        // Declare DLQ (dead-letter queue)
        await _channel.QueueDeclareAsync(
            queue:      $"{QueueName}.dlq",
            durable:    true,
            exclusive:  false,
            autoDelete: false,
            cancellationToken: cancellationToken);

        await _channel.BasicQosAsync(
            prefetchSize:  0,
            prefetchCount: 10,
            global:        false,
            cancellationToken: cancellationToken);

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += OnMessageAsync;

        await _channel.BasicConsumeAsync(
            queue:    QueueName,
            autoAck:  false,
            consumer: consumer,
            cancellationToken: cancellationToken);

        _logger.LogInformation("Consumer started on queue {Queue}", QueueName);
    }

    private async Task OnMessageAsync(object sender, BasicDeliverEventArgs ea)
    {
        string? body = null;
        try
        {
            body = Encoding.UTF8.GetString(ea.Body.Span);

            var msg = JsonSerializer.Deserialize<CreateBookingOrderMessage>(body,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (msg is null)
            {
                _logger.LogWarning("Null payload on queue {Queue}. Nacking to DLQ.", QueueName);
                await _channel!.BasicNackAsync(ea.DeliveryTag, multiple: false, requeue: false);
                return;
            }

            // ── Dispatch to MediatR Persistor ─────────────────────
            await using var scope   = _scopeFactory.CreateAsyncScope();
            var mediator            = scope.ServiceProvider.GetRequiredService<IMediator>();

            await mediator.Send(new CreateBookingOrderPersistorCommand(msg));

            await _channel!.BasicAckAsync(ea.DeliveryTag, multiple: false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error processing message on queue {Queue}. Body: {Body}", QueueName, body);

            // Nack without requeue — goes to DLQ
            await _channel!.BasicNackAsync(ea.DeliveryTag, multiple: false, requeue: false);
        }
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_channel is not null)    await _channel.CloseAsync(cancellationToken);
        if (_connection is not null) await _connection.CloseAsync(cancellationToken);
    }
}
