using Microsoft.Extensions.Logging;

namespace UserAuth.Worker.Workers;

/// <summary>
/// Thin lifecycle wrapper around <see cref="IConsumerService"/> instances.
/// Adds structured logging around each consumer lifecycle call.
/// </summary>
public sealed class WorkerOrchestrator
{
    private readonly ILogger<WorkerOrchestrator> _logger;

    public WorkerOrchestrator(ILogger<WorkerOrchestrator> logger)
    {
        _logger = logger;
    }

    public async Task StartConsumerAsync(IConsumerService consumer, CancellationToken cancellationToken)
    {
        var startTime = DateTime.UtcNow;
        _logger.LogInformation("Starting consumer {Consumer} at {StartTime:O}", consumer.Name, startTime);

        try
        {
            await consumer.StartAsync(cancellationToken);
            _logger.LogInformation("Consumer {Consumer} started successfully", consumer.Name);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Consumer {Consumer} failed to start: {Message}", consumer.Name, ex.Message);
            throw;
        }
    }

    public async Task StopConsumerAsync(IConsumerService consumer, CancellationToken cancellationToken)
    {
        _logger.LogInformation("Stopping consumer {Consumer}", consumer.Name);

        try
        {
            await consumer.StopAsync(cancellationToken);
            _logger.LogInformation("Consumer {Consumer} stopped", consumer.Name);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Consumer {Consumer} did not stop cleanly: {Message}", consumer.Name, ex.Message);
        }
    }
}
