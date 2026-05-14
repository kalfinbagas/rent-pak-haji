using RentPakHaji.Common.Domain.Primitives;

namespace Vehicle.Domain.Entities;

/// <summary>Lookup kategori kendaraan (SUV, MPV, City Car, Matic, Bebek, dll).</summary>
public sealed class VehicleCategory : AuditableEntity
{
    public string Code { get; private set; } = string.Empty;           // SUV, MPV, CITY_CAR …
    public string Name { get; private set; } = string.Empty;
    public string VehicleType { get; private set; } = string.Empty;    // CAR | MOTORCYCLE
    public string? Description { get; private set; }

    private VehicleCategory() { }

    public static VehicleCategory Create(
        string code,
        string name,
        string vehicleType,
        string? description,
        string createdBy)
    {
        return new VehicleCategory
        {
            Id         = Guid.NewGuid(),
            Code        = code.ToUpperInvariant(),
            Name        = name,
            VehicleType = vehicleType.ToUpperInvariant(),
            Description = description,
            CreatedBy   = createdBy,
            CreatedAt   = DateTime.UtcNow,
            IsActive    = true,
            Version     = 1
        };
    }
}
