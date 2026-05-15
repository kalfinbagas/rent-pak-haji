using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using RabbitMQ.Client;
using UserAuth.Worker.Consumers;
using UserAuth.Worker.Workers;

namespace UserAuth.Worker.Extensions;

public static class DependencyInjection
{
    public static IServiceCollection AddWorkerServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // ── RabbitMQ connection factory ────────────────────────────
        services.AddSingleton<IConnectionFactory>(_ => new ConnectionFactory
        {
            HostName = configuration["RabbitMq:Host"]     ?? "localhost",
            Port     = int.Parse(configuration["RabbitMq:Port"] ?? "5672"),
            UserName = configuration["RabbitMq:Username"] ?? "guest",
            Password = configuration["RabbitMq:Password"] ?? "guest",
        });

        // ── Shared IConnection for IRabbitMqPublisher ──────────────
        services.AddSingleton<IConnection>(sp =>
        {
            var factory = sp.GetRequiredService<IConnectionFactory>();
            return factory.CreateConnectionAsync().GetAwaiter().GetResult();
        });

        // ── Orchestrator ───────────────────────────────────────────
        services.AddSingleton<WorkerOrchestrator>();

        // ── Consumers (singleton — hold open channel for lifetime) ─
        services.AddSingleton<RegisterCustomerConsumer>();
        services.AddSingleton<RegisterCustomerDlqConsumer>();
        services.AddSingleton<RegisterOperationalConsumer>();
        services.AddSingleton<RegisterOperationalDlqConsumer>();
        services.AddSingleton<VerifyCustomerConsumer>();
        services.AddSingleton<BlockCustomerConsumer>();

        // ── Register as IConsumerService so MainWorker can enumerate them ─
        services.AddSingleton<IConsumerService>(sp => sp.GetRequiredService<RegisterCustomerConsumer>());
        services.AddSingleton<IConsumerService>(sp => sp.GetRequiredService<RegisterCustomerDlqConsumer>());
        services.AddSingleton<IConsumerService>(sp => sp.GetRequiredService<RegisterOperationalConsumer>());
        services.AddSingleton<IConsumerService>(sp => sp.GetRequiredService<RegisterOperationalDlqConsumer>());
        services.AddSingleton<IConsumerService>(sp => sp.GetRequiredService<VerifyCustomerConsumer>());
        services.AddSingleton<IConsumerService>(sp => sp.GetRequiredService<BlockCustomerConsumer>());

        // ── MainWorker — the single IHostedService ─────────────────
        services.AddHostedService<MainWorker>();

        return services;
    }
}
