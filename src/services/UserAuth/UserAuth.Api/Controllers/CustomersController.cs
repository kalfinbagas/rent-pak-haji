using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using UserAuth.Api.Controllers.Abstract;
using UserAuth.Application.UseCases.BlockCustomer;
using UserAuth.Application.UseCases.GetCustomerById;
using UserAuth.Application.UseCases.VerifyCustomer;

namespace UserAuth.Api.Controllers;

[Authorize]
[Route("api/v1/customers")]
public sealed class CustomersController : ApiControllerBase
{
    /// <summary>Get customer details by ID.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(CustomerDetailResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        var result = await Mediator.Send(new GetCustomerByIdQuery(id), cancellationToken);
        return FromResult(result);
    }

    /// <summary>Verify a customer (SuperAdmin or Operational).</summary>
    [HttpPut("{id:guid}/verify")]
    [Authorize(Roles = "SuperAdmin,Operational")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> Verify(Guid id, CancellationToken cancellationToken)
    {
        var result = await Mediator.Send(new VerifyCustomerCommand(id), cancellationToken);
        return FromResult(result);
    }

    /// <summary>Block a customer (SuperAdmin or Operational).</summary>
    [HttpPut("{id:guid}/block")]
    [Authorize(Roles = "SuperAdmin,Operational")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> Block(Guid id, CancellationToken cancellationToken)
    {
        var result = await Mediator.Send(new BlockCustomerCommand(id), cancellationToken);
        return FromResult(result);
    }
}
