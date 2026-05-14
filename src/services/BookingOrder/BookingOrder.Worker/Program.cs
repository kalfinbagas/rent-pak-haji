using BookingOrder.Application.Persistors.CreateBookingOrder;
using BookingOrder.Application.Usecase.CreateBookingOrder;
using BookingOrder.Infrastructure;
using BookingOrder.Worker.Extensions;
using FluentValidation;
using MediatR;
using RentPakHaji.Common.Application.Behaviours;
using Serilog;
using Serilog.Events;

// ── Bootstrap Logger ──────────────────────────────────────────
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    Log.Information("Starting BookingOrder Worker...");

    var builder = Host.CreateApplicationBuilder(args);

    // ── Serilog ────────────────────────────────────────────────
    builder.Services.AddSerilog((sp, lc) => lc
        .ReadFrom.Configuration(builder.Configuration)
        .Enrich.FromLogContext()
        .WriteTo.Console()
        .WriteTo.Seq(builder.Configuration["Seq:Url"] ?? "http://localhost:5341"));

    // ── MediatR (Persistors + Behaviours) ─────────────────────
    builder.Services.AddMediatR(cfg =>
    {
        cfg.RegisterServicesFromAssembly(typeof(CreateBookingOrderPersistorHandler).Assembly);
        cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehaviour<,>));
    });

    builder.Services.AddValidatorsFromAssemblyContaining<CreateBookingOrderValidator>();

    // ── Infrastructure (DB, services) ─────────────────────────
    // IRabbitMqPublisher is registered here (used by Persistor to publish SoftBookingCreated)
    builder.Services.AddInfrastructure(builder.Configuration);

    // ── Worker consumers + MainWorker ──────────────────────────
    builder.Services.AddWorkerServices(builder.Configuration);

    var host = builder.Build();
    await host.RunAsync();
}
catch (Exception ex)
{
    Log.Fatal(ex, "BookingOrder Worker terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
