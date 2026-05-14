using MediatR;
using Microsoft.AspNetCore.Mvc;
using RentPakHaji.Common.Application;

namespace BookingOrder.Api.Controllers.Abstract;

/// <summary>
/// Base controller for all BookingOrder API controllers.
///
/// Features (adapted from SERA's AbstractController):
///   • Lazy <see cref="IMediator"/> resolved from DI container
///   • <see cref="OkResult"/> / <see cref="BadRequestObjectResult"/> routing via <see cref="ToActionResult{T}"/>
///
/// All controllers inherit from this instead of <see cref="ControllerBase"/> directly.
/// </summary>
[ApiController]
public abstract class ApiControllerBase : ControllerBase
{
    private IMediator? _mediator;

    /// <summary>Lazily resolved from the current request's service provider.</summary>
    protected IMediator Mediator =>
        _mediator ??= HttpContext.RequestServices.GetRequiredService<IMediator>();

    /// <summary>
    /// Maps a <see cref="Result{T}"/> to an <see cref="ActionResult{T}"/>.
    /// Success → 200 OK, Failure → 400 Bad Request with error details.
    /// </summary>
    protected ActionResult<T> ToActionResult<T>(Result<T> result)
    {
        return result.IsSuccess
            ? Ok(result.Value)
            : BadRequest(new { result.ErrorCode, result.ErrorMessage });
    }

    /// <summary>
    /// Maps a <see cref="Result{T}"/> to 202 Accepted for async write operations.
    /// Failure → 400 Bad Request.
    /// </summary>
    protected ActionResult ToAccepted<T>(Result<T> result, object? value = null)
    {
        if (result.IsFailure)
            return BadRequest(new { result.ErrorCode, result.ErrorMessage });

        return Accepted(value ?? result.Value!);
    }
}
