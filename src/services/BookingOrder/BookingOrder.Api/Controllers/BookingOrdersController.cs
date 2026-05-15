using BookingOrder.Api.Controllers.Abstract;
using BookingOrder.Application.Usecase.CreateBookingOrder;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BookingOrder.Api.Controllers;

/// <summary>
/// Booking Order management endpoints.
/// All writes are async: the API validates, publishes to the message broker,
/// and returns 202 Accepted. The Worker persists and raises domain events.
/// </summary>
[Authorize]
[Route("api/v1/booking-orders")]
public sealed class BookingOrdersController : ApiControllerBase
{
    /// <summary>
    /// Submit a new booking order.
    /// Returns 202 Accepted with a pre-assigned <c>BookingOrderId</c> the client can poll.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(CreateBookingOrderResponse), StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Create(
        [FromBody] CreateBookingOrderCommand command,
        CancellationToken cancellationToken)
    {
        var result = await Mediator.Send(command, cancellationToken);

        if (result.IsFailure)
            return BadRequest(new { result.ErrorCode, result.ErrorMessage });

        return Accepted(new
        {
            result.Value!.BookingOrderId,
            result.Value.TransactionId,
            result.Value.Status,
            Message = $"Booking order sedang diproses. " +
                      $"Cek status di GET /api/v1/booking-orders/{result.Value.BookingOrderId}"
        });
    }

    /// <summary>Get booking order by ID (polling endpoint).</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        // TODO: implement GetBookingOrderByIdQuery
        await Task.CompletedTask;
        return Ok(new { id, message = "TODO: implement GetBookingOrderByIdQuery" });
    }
}
