namespace BookingOrder.Worker.Workers;

/// <summary>
/// Abstraction for a long-running RabbitMQ consumer managed by <see cref="WorkerOrchestrator"/>.
/// Each consumer implements this interface so the orchestrator can start, stop, and log them uniformly.
/// </summary>
public interface IConsumerService
{
    /// <summary>Human-readable name used in log messages.</summary>
    string Name { get; }

    /// <summary>Begin consuming messages. Returns as soon as the listener is registered (non-blocking).</summary>
    Task StartAsync(CancellationToken cancellationToken);

    /// <summary>Gracefully stop consuming and release resources.</summary>
    Task StopAsync(CancellationToken cancellationToken);
}
