using MediatR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using System.Text.Json;
using UserAuth.Application.Persistors.BlockCustomer;
using UserAuth.Application.UseCases.BlockCustomer;
using UserAuth.Worker.Workers;

namespace UserAuth.Worker.Consumers;

internal sealed class BlockCustomerConsumer : IConsumerService
{
    private const string QueueName = "userauth.customer.block";

    private readonly IConnectionFactory _connectionFactory;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<BlockCustomerConsumer> _logger;

    private IConnection? _connection;
    private IChannel? _channel;

    public string Name => nameof(BlockCustomerConsumer);

    public BlockCustomerConsumer(
        IConnectionFactory connectionFactory,
        IServiceScopeFactory scopeFactory,
        ILogger<BlockCustomerConsumer> logger)
    {
        _connectionFactory = connectionFactory;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        _connection = await _connectionFactory.CreateConnectionAsync(cancellationToken);
        _channel = await _connection.CreateChannelAsync(cancellationToken: cancellationToken);

        await _channel.QueueDeclareAsync(
            queue: QueueName,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: new Dictionary<string, object?>
            {
                ["x-dead-letter-exchange"]    = "",
                ["x-dead-letter-routing-key"] = $"{QueueName}.dlq"
            },
            cancellationToken: cancellationToken);

        await _channel.QueueDeclareAsync(
            queue: $"{QueueName}.dlq",
            durable: true,
            exclusive: false,
            autoDelete: false,
            cancellationToken: cancellationToken);

        await _channel.BasicQosAsync(
            prefetchSize: 0,
            prefetchCount: 10,
            global: false,
            cancellationToken: cancellationToken);

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += OnMessageAsync;

        await _channel.BasicConsumeAsync(
            queue: QueueName,
            autoAck: false,
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

            var msg = JsonSerializer.Deserialize<BlockCustomerMessage>(body,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (msg is null)
            {
                _logger.LogWarning("Null payload on queue {Queue}. Nacking to DLQ.", QueueName);
                await _channel!.BasicNackAsync(ea.DeliveryTag, multiple: false, requeue: false);
                return;
            }

            await using var scope = _scopeFactory.CreateAsyncScope();
            var mediator = scope.ServiceProvider.GetRequiredService<IMediator>();

            var command = new BlockCustomerPersistorCommand { CustomerId = msg.CustomerId };

            var result = await mediator.Send(command);
            if (result.IsFailure)
                throw new InvalidOperationException($"Persistor failed: {result.ErrorCode} - {result.ErrorMessage}");

            _logger.LogInformation("Customer {Id} blocked successfully", msg.CustomerId);
            await _channel!.BasicAckAsync(ea.DeliveryTag, multiple: false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing message on queue {Queue}. Body: {Body}", QueueName, body);
            await _channel!.BasicNackAsync(ea.DeliveryTag, multiple: false, requeue: false);
        }
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_channel is not null)    await _channel.CloseAsync(cancellationToken);
        if (_connection is not null) await _connection.CloseAsync(cancellationToken);
    }
}
