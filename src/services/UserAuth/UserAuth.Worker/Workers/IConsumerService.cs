namespace UserAuth.Worker.Workers;

/// <summary>
/// Abstraction for a long-running RabbitMQ consumer managed by <see cref="WorkerOrchestrator"/>.
/// </summary>
public interface IConsumerService
{
    /// <summary>Human-readable name used in log messages.</summary>
    string Name { get; }

    /// <summary>Begin consuming messages. Returns as soon as the listener is registered (non-blocking).</summary>
    Task StartAsync(CancellationToken ct);

    /// <summary>Gracefully stop consuming and release resources.</summary>
    Task StopAsync(CancellationToken ct);
}
