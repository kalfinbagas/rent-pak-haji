using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using RentPakHaji.Common.Broker.Abstractions;
using RentPakHaji.Common.Broker.Publisher;
using UserAuth.Application.Abstractions;
using UserAuth.Infrastructure.Persistence;
using UserAuth.Infrastructure.Services;

namespace UserAuth.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // ── Database ───────────────────────────────────────────
        services.AddDbContext<UserAuthDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("UserAuthDb"),
                npgsql =>
                {
                    npgsql.MigrationsAssembly(typeof(UserAuthDbContext).Assembly.FullName);
                    npgsql.EnableRetryOnFailure(maxRetryCount: 3);
                }));

        services.AddScoped<IUserAuthDbContext>(sp =>
            sp.GetRequiredService<UserAuthDbContext>());

        // ── Services ───────────────────────────────────────────
        services.AddScoped<IPasswordHasher, BcryptPasswordHasher>();
        services.AddSingleton<IFileStorageService, LocalFileStorageService>();
        services.AddScoped<IJwtTokenService, JwtTokenService>();

        // ── RabbitMQ publisher ─────────────────────────────────
        // IConnectionFactory is intentionally NOT registered here — each process
        // (Api and Worker) registers its own factory so connection settings can
        // differ per deployment.
        services.AddSingleton<IRabbitMqPublisher, RabbitMqPublisher>();

        return services;
    }
}
