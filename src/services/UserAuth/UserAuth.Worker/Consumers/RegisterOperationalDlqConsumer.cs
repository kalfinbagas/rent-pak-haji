using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using UserAuth.Worker.Workers;

namespace UserAuth.Worker.Consumers;

/// <summary>
/// Dead-Letter Queue consumer for <c>userauth.operational.register.dlq</c>.
/// Logs failed messages for investigation.
/// </summary>
public sealed class RegisterOperationalDlqConsumer : IConsumerService
{
    private const string QueueName = "userauth.operational.register.dlq";

    private readonly IConnectionFactory _connectionFactory;
    private readonly ILogger<RegisterOperationalDlqConsumer> _logger;

    private IConnection? _connection;
    private IChannel? _channel;

    public string Name => nameof(RegisterOperationalDlqConsumer);

    public RegisterOperationalDlqConsumer(
        IConnectionFactory connectionFactory,
        ILogger<RegisterOperationalDlqConsumer> logger)
    {
        _connectionFactory = connectionFactory;
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
            cancellationToken: cancellationToken);

        await _channel.BasicQosAsync(
            prefetchSize: 0,
            prefetchCount: 5,
            global: false,
            cancellationToken: cancellationToken);

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += OnDlqMessageAsync;

        await _channel.BasicConsumeAsync(
            queue: QueueName,
            autoAck: false,
            consumer: consumer,
            cancellationToken: cancellationToken);

        _logger.LogInformation("DLQ consumer started on queue {Queue}", QueueName);
    }

    private async Task OnDlqMessageAsync(object sender, BasicDeliverEventArgs ea)
    {
        var body = Encoding.UTF8.GetString(ea.Body.Span);

        string? reason = null;
        string? origQueue = null;

        if (ea.BasicProperties.Headers?.TryGetValue("x-death", out var deathObj) == true &&
            deathObj is List<object> deaths && deaths.Count > 0 &&
            deaths[0] is Dictionary<string, object> death)
        {
            reason    = death.TryGetValue("reason", out var r) ? r?.ToString() : null;
            origQueue = death.TryGetValue("queue",  out var q) ? q?.ToString() : null;
        }

        _logger.LogError(
            "DLQ message received. OriginalQueue={OrigQueue}, Reason={Reason}, Body={Body}",
            origQueue, reason, body);

        await _channel!.BasicAckAsync(ea.DeliveryTag, multiple: false);
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_channel is not null)    await _channel.CloseAsync(cancellationToken);
        if (_connection is not null) await _connection.CloseAsync(cancellationToken);
    }
}
