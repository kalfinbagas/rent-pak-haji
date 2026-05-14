namespace BookingOrder.Application.Abstractions;

/// <summary>Generates unique booking codes in format RPK-YYYYMMDD-XXXX.</summary>
public interface IBookingCodeGenerator
{
    Task<string> GenerateAsync(CancellationToken cancellationToken = default);
}
