using RentPakHaji.Common.Domain.Primitives;

namespace Vehicle.Domain.Entities;

/// <summary>Lookup tipe transmisi (Manual, Automatic, CVT, DCT, AMT).</summary>
public sealed class VehicleTransmissionType : AuditableEntity
{
    public string Code { get; private set; } = string.Empty;   // MANUAL, AUTOMATIC, CVT …
    public string Name { get; private set; } = string.Empty;

    private VehicleTransmissionType() { }

    public static VehicleTransmissionType Create(string code, string name, string createdBy)
    {
        return new VehicleTransmissionType
        {
            Id        = Guid.NewGuid(),
            Code      = code.ToUpperInvariant(),
            Name      = name,
            CreatedBy = createdBy,
            CreatedAt = DateTime.UtcNow,
            IsActive  = true,
            Version   = 1
        };
    }
}
