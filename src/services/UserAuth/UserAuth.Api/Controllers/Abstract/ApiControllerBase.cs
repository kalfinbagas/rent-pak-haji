using MediatR;
using Microsoft.AspNetCore.Mvc;
using RentPakHaji.Common.Application;

namespace UserAuth.Api.Controllers.Abstract;

[ApiController]
public abstract class ApiControllerBase : ControllerBase
{
    private IMediator? _mediator;

    protected IMediator Mediator =>
        _mediator ??= HttpContext.RequestServices.GetRequiredService<IMediator>();

    protected IActionResult FromResult(Result result)
    {
        return result.IsSuccess
            ? Ok()
            : BadRequest(new { result.ErrorCode, result.ErrorMessage });
    }

    protected IActionResult FromResult<T>(Result<T> result)
    {
        return result.IsSuccess
            ? Ok(result.Value)
            : BadRequest(new { result.ErrorCode, result.ErrorMessage });
    }

    protected ActionResult<T> ToActionResult<T>(Result<T> result)
    {
        return result.IsSuccess
            ? Ok(result.Value)
            : BadRequest(new { result.ErrorCode, result.ErrorMessage });
    }
}
