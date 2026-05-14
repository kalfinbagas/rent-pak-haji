using BookingOrder.Application.Usecase.CreateBookingOrder;
using MediatR;

namespace BookingOrder.Application.Persistors.CreateBookingOrder;

/// <summary>
/// Worker-side command: persists the booking order that the API published.
/// Dispatched by <c>CreateBookingOrderConsumer</c> in the Worker project.
/// </summary>
public sealed record CreateBookingOrderPersistorCommand(
    CreateBookingOrderMessage Message
) : IRequest<Unit>;
