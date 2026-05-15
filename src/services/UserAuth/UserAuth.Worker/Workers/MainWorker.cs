using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace UserAuth.Worker.Workers;

/// <summary>
/// The single <see cref="IHostedService"/> that orchestrates all RabbitMQ consumers.
/// </summary>
public sealed class MainWorker : BackgroundService
{
    private readonly ILogger<MainWorker> _logger;
    private readonly WorkerOrchestrator _orchestrator;
    private readonly IEnumerable<IConsumerService> _consumers;

    public MainWorker(
        ILogger<MainWorker> logger,
        WorkerOrchestrator orchestrator,
        IEnumerable<IConsumerService> consumers)
    {
        _logger    = logger;
        _orchestrator = orchestrator;
        _consumers = consumers;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("UserAuth Worker starting...");

        try
        {
            foreach (var consumer in _consumers)
                await _orchestrator.StartConsumerAsync(consumer, stoppingToken);

            _logger.LogInformation("UserAuth Worker is running. Listening for messages...");

            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException)
        {
            // Normal shutdown — no action needed
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "UserAuth Worker encountered a fatal error: {Message}", ex.Message);
            throw;
        }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("UserAuth Worker stopping...");

        foreach (var consumer in _consumers.Reverse())
            await _orchestrator.StopConsumerAsync(consumer, cancellationToken);

        await base.StopAsync(cancellationToken);
        _logger.LogInformation("UserAuth Worker stopped");
    }
}
