using BookingOrder.Worker.Consumers;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BookingOrder.Worker.Workers;

/// <summary>
/// The single <see cref="IHostedService"/> that orchestrates all RabbitMQ consumers.
///
/// Pattern (adapted from SERA's MainService):
///   ExecuteAsync → start each consumer via <see cref="WorkerOrchestrator"/>
///   StopAsync    → stop each consumer in reverse order
///
/// Add new consumers here when the service grows.
/// </summary>
public sealed class MainWorker : BackgroundService
{
    private readonly ILogger<MainWorker>    _logger;
    private readonly WorkerOrchestrator     _orchestrator;

    // ── Consumers ────────────────────────────────────────────────
    private readonly CreateBookingOrderConsumer    _createConsumer;
    private readonly CreateBookingOrderDlqConsumer _dlqConsumer;

    public MainWorker(
        ILogger<MainWorker>            logger,
        WorkerOrchestrator             orchestrator,
        CreateBookingOrderConsumer     createConsumer,
        CreateBookingOrderDlqConsumer  dlqConsumer)
    {
        _logger         = logger;
        _orchestrator   = orchestrator;
        _createConsumer = createConsumer;
        _dlqConsumer    = dlqConsumer;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("BookingOrder Worker starting...");

        try
        {
            // Start main consumers first, then DLQ
            await _orchestrator.StartConsumerAsync(_createConsumer, stoppingToken);
            await _orchestrator.StartConsumerAsync(_dlqConsumer,    stoppingToken);

            _logger.LogInformation("BookingOrder Worker is running. Listening for messages...");

            // Keep alive until host requests shutdown
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException)
        {
            // Normal shutdown — no action needed
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "BookingOrder Worker encountered a fatal error: {Message}", ex.Message);
            throw;
        }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("BookingOrder Worker stopping...");

        await _orchestrator.StopConsumerAsync(_dlqConsumer,    cancellationToken);
        await _orchestrator.StopConsumerAsync(_createConsumer, cancellationToken);

        await base.StopAsync(cancellationToken);

        _logger.LogInformation("BookingOrder Worker stopped");
    }
}
