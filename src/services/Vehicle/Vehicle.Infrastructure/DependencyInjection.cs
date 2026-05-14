using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using RabbitMQ.Client;
using Vehicle.Application.Abstractions;
using Vehicle.Application.Consumers;
using Vehicle.Infrastructure.Persistence;

namespace Vehicle.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // ── Database ───────────────────────────────────────────────
        var connectionString = configuration.GetConnectionString("VehicleDb")
            ?? throw new InvalidOperationException("ConnectionString 'VehicleDb' is not configured.");

        services.AddDbContext<VehicleDbContext>(opts =>
            opts.UseNpgsql(connectionString, npgsql =>
            {
                npgsql.MigrationsAssembly(typeof(VehicleDbContext).Assembly.FullName);
                npgsql.EnableRetryOnFailure(maxRetryCount: 3);
            }));

        services.AddScoped<IVehicleDbContext>(sp =>
            sp.GetRequiredService<VehicleDbContext>());

        // ── RabbitMQ connection factory (singleton) ────────────────
        services.AddSingleton<IConnectionFactory>(_ =>
        {
            var host     = configuration["RabbitMq:Host"]     ?? "localhost";
            var port     = int.Parse(configuration["RabbitMq:Port"] ?? "5672");
            var username = configuration["RabbitMq:Username"] ?? "guest";
            var password = configuration["RabbitMq:Password"] ?? "guest";

            return new ConnectionFactory
            {
                HostName = host,
                Port     = port,
                UserName = username,
                Password = password,
                DispatchConsumersAsync = true
            };
        });

        // ── Background consumers ───────────────────────────────────
        services.AddHostedService<ReplicateSoftBookingConsumer>();
        services.AddHostedService<ReleaseSoftBookingConsumer>();

        return services;
    }
}
