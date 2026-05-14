namespace BookingOrder.Application.Usecase.CreateBookingOrder;

/// <summary>
/// Returned immediately (202 Accepted) after the API publishes the command.
/// The client uses <see cref="BookingOrderId"/> to poll for the final result.
/// </summary>
public sealed record CreateBookingOrderResponse(
    Guid   BookingOrderId,
    string TransactionId,
    string Status = "PROCESSING"
);
