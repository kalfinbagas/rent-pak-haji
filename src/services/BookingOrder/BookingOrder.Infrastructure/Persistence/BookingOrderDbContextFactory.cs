using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace BookingOrder.Infrastructure.Persistence;

/// <summary>
/// Design-time factory so EF Tools can create a <see cref="BookingOrderDbContext"/>
/// without needing the full API/Worker startup project.
///
/// Usage (from src/services/BookingOrder/):
///   dotnet ef migrations add InitialCreate --project BookingOrder.Infrastructure
///   dotnet ef database update          --project BookingOrder.Infrastructure
/// </summary>
public sealed class BookingOrderDbContextFactory
    : IDesignTimeDbContextFactory<BookingOrderDbContext>
{
    public BookingOrderDbContext CreateDbContext(string[] args)
    {
        // Resolve config from the Infrastructure project's own folder first,
        // then fall back to the Api folder (works from either working directory).
        var config = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json",             optional: true)
            .AddJsonFile("appsettings.Development.json", optional: true)
            .AddEnvironmentVariables()
            .Build();

        var connectionString =
            config.GetConnectionString("BookingOrderDb")
            ?? "Host=localhost;Port=5432;Database=rpk_bookingorder;Username=rpk_admin;Password=RpkSecure2026!";

        var optionsBuilder = new DbContextOptionsBuilder<BookingOrderDbContext>();
        optionsBuilder.UseNpgsql(
            connectionString,
            npgsql => npgsql.MigrationsAssembly(typeof(BookingOrderDbContext).Assembly.FullName));

        return new BookingOrderDbContext(optionsBuilder.Options);
    }
}
