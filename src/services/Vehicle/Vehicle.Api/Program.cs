using FluentValidation;
using MediatR;
using RentPakHaji.Common.Application.Behaviours;
using Serilog;
using Serilog.Events;
using Vehicle.Application.Consumers;
using Vehicle.Infrastructure;

// ── Bootstrap Logger ──────────────────────────────────────────
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    Log.Information("Starting Vehicle Service...");

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
        cfg.RegisterServicesFromAssembly(typeof(ReplicateSoftBookingConsumer).Assembly);
        cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehaviour<,>));
    });

    builder.Services.AddValidatorsFromAssembly(typeof(ReplicateSoftBookingConsumer).Assembly);

    // ── Infrastructure (DB, etc.) ─────────────────────────────
    builder.Services.AddInfrastructure(builder.Configuration);

    // ── API ────────────────────────────────────────────────────
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen(c =>
    {
        c.SwaggerDoc("v1", new() { Title = "Vehicle Service", Version = "v1" });
    });

    // ── Health Check ───────────────────────────────────────────
    builder.Services.AddHealthChecks()
        .AddNpgsql(builder.Configuration.GetConnectionString("VehicleDb")!);

    var app = builder.Build();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI();
    }

    app.UseSerilogRequestLogging();
    app.MapControllers();
    app.MapHealthChecks("/health");

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Vehicle Service terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
