using BookingOrder.Api.Middleware;
using BookingOrder.Application.Usecase.CreateBookingOrder;
using BookingOrder.Infrastructure;
using FluentValidation;
using MediatR;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using RabbitMQ.Client;
using RentPakHaji.Common.Application.Behaviours;
using Scalar.AspNetCore;
using Serilog;
using Serilog.Events;
using System.Text;

// ── Bootstrap Logger ──────────────────────────────────────────
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    Log.Information("Starting BookingOrder API...");

    var builder = WebApplication.CreateBuilder(args);

    // ── Serilog ────────────────────────────────────────────────
    builder.Host.UseSerilog((ctx, lc) => lc
        .ReadFrom.Configuration(ctx.Configuration)
        .Enrich.FromLogContext()
        .WriteTo.Console()
        .WriteTo.Seq(ctx.Configuration["Seq:Url"] ?? "http://localhost:5341"));

    // ── MediatR + Validation Pipeline ─────────────────────────
    builder.Services.AddMediatR(cfg =>
    {
        cfg.RegisterServicesFromAssembly(typeof(CreateBookingOrderHandler).Assembly);
        cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehaviour<,>));
    });

    builder.Services.AddValidatorsFromAssemblyContaining<CreateBookingOrderValidator>();

    // ── Infrastructure (DB, domain services) ──────────────────
    builder.Services.AddInfrastructure(builder.Configuration);

    // ── RabbitMQ connection factory (API-owned, for publisher) ─
    // DispatchConsumersAsync was removed in RabbitMQ.Client 7.x — async is now the default.
    builder.Services.AddSingleton<IConnectionFactory>(_ => new ConnectionFactory
    {
        HostName = builder.Configuration["RabbitMq:Host"]     ?? "localhost",
        Port     = int.Parse(builder.Configuration["RabbitMq:Port"] ?? "5672"),
        UserName = builder.Configuration["RabbitMq:Username"] ?? "guest",
        Password = builder.Configuration["RabbitMq:Password"] ?? "guest",
    });

    builder.Services.AddSingleton<IConnection>(sp =>
    {
        var factory = sp.GetRequiredService<IConnectionFactory>();
        return factory.CreateConnectionAsync().GetAwaiter().GetResult();
    });

    // ── JWT Bearer Authentication ──────────────────────────────
    var jwtKey    = builder.Configuration["Jwt:Key"]
        ?? throw new InvalidOperationException("Jwt:Key is not configured.");
    var jwtIssuer = builder.Configuration["Jwt:Issuer"]   ?? "rent-pak-haji";
    var jwtAud    = builder.Configuration["Jwt:Audience"] ?? "rent-pak-haji-clients";

    builder.Services
        .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(opts =>
        {
            opts.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer           = true,
                ValidateAudience         = true,
                ValidateLifetime         = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer              = jwtIssuer,
                ValidAudience            = jwtAud,
                IssuerSigningKey         = new SymmetricSecurityKey(
                                               Encoding.UTF8.GetBytes(jwtKey)),
                ClockSkew = TimeSpan.Zero
            };
        });

    builder.Services.AddAuthorization();

    // ── API + OpenAPI (native .NET 10 / Scalar UI) ────────────
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddOpenApi(options =>
    {
        options.AddDocumentTransformer((doc, _, _) =>
        {
            doc.Info = new() { Title = "BookingOrder Service API", Version = "v1" };
            return Task.CompletedTask;
        });
    });

    // ── Health Check ───────────────────────────────────────────
    builder.Services.AddHealthChecks();

    var app = builder.Build();

    // ── Middleware Pipeline ────────────────────────────────────
    // 1. Global exception handler — must be outermost
    app.UseGlobalExceptionHandler();

    // 2. OpenAPI + Scalar UI (dev only)
    if (app.Environment.IsDevelopment())
    {
        app.MapOpenApi();
        app.MapScalarApiReference(opts =>
            opts.WithTitle("BookingOrder API")
                .WithPreferredScheme("Bearer"));
    }

    // 3. Request logging
    app.UseSerilogRequestLogging();

    // 4. Transaction-Id header validation
    app.UseTransactionIdValidation();

    // 5. Auth
    app.UseAuthentication();
    app.UseAuthorization();

    app.MapControllers();
    app.MapHealthChecks("/health").AllowAnonymous();

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "BookingOrder API terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
