using BookingOrder.Application.Abstractions;

namespace BookingOrder.Infrastructure.Services;

internal sealed class DateTimeProvider : IDateTimeProvider
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
