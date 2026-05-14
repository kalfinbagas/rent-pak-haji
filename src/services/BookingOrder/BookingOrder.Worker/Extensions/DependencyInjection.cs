using BookingOrder.Worker.Consumers;
using BookingOrder.Worker.Workers;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using RabbitMQ.Client;

namespace BookingOrder.Worker.Extensions;

public static class DependencyInjection
{
    public static IServiceCollection AddWorkerServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // ── RabbitMQ connection factory ────────────────────────────
        // DispatchConsumersAsync was removed in RabbitMQ.Client 7.x — async dispatch is now the default.
        services.AddSingleton<IConnectionFactory>(_ => new ConnectionFactory
        {
            HostName = configuration["RabbitMq:Host"]     ?? "localhost",
            Port     = int.Parse(configuration["RabbitMq:Port"] ?? "5672"),
            UserName = configuration["RabbitMq:Username"] ?? "guest",
            Password = configuration["RabbitMq:Password"] ?? "guest",
        });

        // ── Shared IConnection for IRabbitMqPublisher (used by Persistor handlers) ──
        services.AddSingleton<IConnection>(sp =>
        {
            var factory = sp.GetRequiredService<IConnectionFactory>();
            return factory.CreateConnectionAsync().GetAwaiter().GetResult();
        });

        // ── Orchestrator (singleton — just logging, no state) ──────
        services.AddSingleton<WorkerOrchestrator>();

        // ── Consumers (singleton — hold open channel for their lifetime) ──
        services.AddSingleton<CreateBookingOrderConsumer>();
        services.AddSingleton<CreateBookingOrderDlqConsumer>();

        // ── MainWorker — the single IHostedService ─────────────────
        services.AddHostedService<MainWorker>();

        return services