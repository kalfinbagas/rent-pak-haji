using Microsoft.AspNetCore.Mvc;

namespace Vehicle.Api.Controllers;

[ApiController]
[Route("api/vehicles")]
public sealed class VehiclesController : ControllerBase
{
    /// <summary>List available vehicles for a given pool, type, and date window.</summary>
    [HttpGet("available")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public IActionResult GetAvailable(
        [FromQuery] Guid poolLocationId,
        [FromQuery] string vehicleType,
        [FromQuery] DateTime startDate,
        [FromQuery] DateTime endDate,
        CancellationToken cancellationToken)
    {
        // TODO: implement GetAvailableVehiclesQuery
        return Ok(new { poolLocationId, vehicleType, startDate, endDate, message = "TODO: implement GetAvailableVehiclesQuery" });
    }

    /// <summary>Get vehicle detail by ID.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public IActionResult GetById(Guid id, CancellationToken cancellationToken)
    {
        // TODO: implement GetVehicleByIdQuery
        return Ok(new { id, message = "TODO: implement GetVehicleByIdQuery" });
    }
}
