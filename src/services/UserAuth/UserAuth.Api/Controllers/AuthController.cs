using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using UserAuth.Api.Controllers.Abstract;
using UserAuth.Application.UseCases.LoginCustomer;
using UserAuth.Application.UseCases.LoginOperational;
using UserAuth.Application.UseCases.RegisterCustomer;
using UserAuth.Application.UseCases.RegisterOperational;
using UserAuth.Domain.Enums;

namespace UserAuth.Api.Controllers;

[Route("api/v1/auth")]
public sealed class AuthController : ApiControllerBase
{
    /// <summary>Register a new customer account (multipart/form-data).</summary>
    [HttpPost("customer/register")]
    [AllowAnonymous]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(RegisterCustomerResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> RegisterCustomer(
        [FromForm] string fullName,
        [FromForm] DateOnly dateOfBirth,
        [FromForm] string address,
        [FromForm] string phoneNumber,
        [FromForm] string email,
        [FromForm] string password,
        [FromForm] IFormFile ktpPhoto,
        [FromForm] IFormFile? simAPhoto,
        CancellationToken cancellationToken)
    {
        var command = new RegisterCustomerCommand(
            fullName,
            dateOfBirth,
            address,
            phoneNumber,
            email,
            password,
            ktpPhoto.OpenReadStream(),
            ktpPhoto.FileName,
            simAPhoto?.OpenReadStream(),
            simAPhoto?.FileName);

        var result = await Mediator.Send(command, cancellationToken);
        return FromResult(result);
    }

    /// <summary>Customer login — returns JWT token.</summary>
    [HttpPost("customer/login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> LoginCustomer(
        [FromBody] LoginCustomerCommand command,
        CancellationToken cancellationToken)
    {
        var result = await Mediator.Send(command, cancellationToken);
        return FromResult(result);
    }

    /// <summary>Register a new operational user (SuperAdmin only, multipart/form-data).</summary>
    [HttpPost("operational/register")]
    [Authorize(Roles = "SuperAdmin")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(RegisterOperationalResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> RegisterOperational(
        [FromForm] string fullName,
        [FromForm] DateOnly dateOfBirth,
        [FromForm] string address,
        [FromForm] string phoneNumber,
        [FromForm] string email,
        [FromForm] string password,
        [FromForm] OperationalRole role,
        [FromForm] IFormFile ktpPhoto,
        CancellationToken cancellationToken)
    {
        var command = new RegisterOperationalCommand(
            fullName,
            dateOfBirth,
            address,
            phoneNumber,
            email,
            password,
            role,
            ktpPhoto.OpenReadStream(),
            ktpPhoto.FileName);

        var result = await Mediator.Send(command, cancellationToken);
        return FromResult(result);
    }

    /// <summary>Operational user login — returns JWT token.</summary>
    [HttpPost("operational/login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> LoginOperational(
        [FromBody] LoginOperationalCommand command,
        CancellationToken cancellationToken)
    {
        var result = await Mediator.Send(command, cancellationToken);
        return FromResult(result);
    }
}
