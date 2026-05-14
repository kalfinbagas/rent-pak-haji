using BookingOrder.Application.Abstractions;
using BookingOrder.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace BookingOrder.Infrastructure.Services;

/// <summary>
/// Generates booking codes in format RPK-YYYYMMDD-XXXX (e.g. RPK-20260514-0001).
/// Thread-safe via database sequence / count query.
/// </summary>
internal sealed class BookingCodeGenerator : IBookingCodeGenerator
{
    private readonly BookingOrderDbContext _db;

    public BookingCodeGenerator(BookingOrderDbContext db)
    {
        _db = db;
    }

    public async Task<string> GenerateAsync(CancellationToken cancellationToken = default)
    {
        var today = DateTimeOffset.UtcNow.ToString("yyyyMMdd");

        // Count today's orders to generate sequential number
        var prefix = $"RPK-{today}-";
        var countToday = await _db.BookingOrders
            .CountAsync(x => x.BookingCode.StartsWith(prefix), cancellationToken);

        var sequence = (countToday + 1).ToString("D4");
        return $"{prefix}{sequence}";
    }
}
