using RentPakHaji.Common.Domain.Primitives;
using Vehicle.Domain.Enums;

namespace Vehicle.Domain.Entities;

/// <summary>
/// Aggregate root — data utama kendaraan.
/// Navigation: VehicleMovements, VehiclePreparations (append-only children).
/// </summary>
public sealed class MasterVehicle : AuditableEntity
{
    // ── Identifikasi ─────────────────────────────────────────────
    public string LicensePlate      { get; private set; } = string.Empty;
    public string? Vin              { get; private set; }   // Vehicle Identification Number
    public string VehicleType       { get; private set; } = string.Empty; // CAR | MOTORCYCLE
    public string Brand             { get; private set; } = string.Empty;
    public string Model             { get; private set; } = string.Empty;
    public int    Year              { get; private set; }
    public string? Color            { get; private set; }

    // ── FK ke lookup tables ───────────────────────────────────────
    public Guid? VehicleCategoryId      { get; private set; }
    public Guid? TransmissionTypeId     { get; private set; }
    public int?  NumberOfSeats          { get; private set; }
    public int?  NumberOfDoors          { get; private set; }
    public string FuelType              { get; private set; } = "GASOLINE"; // GASOLINE|DIESEL|ELECTRIC|HYBRID
    public string WheelDrive            { get; private set; } = "2WD";      // 2WD|4WD|AWD

    // ── Status & lokasi ───────────────────────────────────────────
    public VehicleStatus Status         { get; private set; } = VehicleStatus.Available;
    public Guid   PoolLocationId        { get; private set; }
    public string PoolLocationName      { get; private set; } = string.Empty; // denorm

    // ── Pricing ───────────────────────────────────────────────────
    public decimal DailyRate            { get; private set; }

    // ── Odometer & kondisi ────────────────────────────────────────
    public int  Odometer                { get; private set; }
    public bool HasObd                  { get; private set; }

    // ── Preparation ───────────────────────────────────────────────
    public PreparationStatus? PreparationStatus     { get; private set; }
    public string?            PreparationActivity   { get; private set; }
    public string?            PreparationActivityStatus { get; private set; }
    public Guid?              PreparationPic        { get; private set; }

    // ── Kondisi ───────────────────────────────────────────────────
    public bool ConditionInMaintenance  { get; private set; }
    public bool ConditionHasBreakdown   { get; private set; }
    public bool ConditionHasOutstanding { get; private set; }

    // ── Pool scheduling ───────────────────────────────────────────
    public DateTimeOffset? PoolInTargetTime { get; private set; }
    public DateTimeOffset? PoolInActualTime { get; private set; }

    // ── Ownership ─────────────────────────────────────────────────
    public OwnershipType OwnershipType  { get; private set; } = OwnershipType.Own;
    public DateOnly? ValidFrom          { get; private set; }
    public DateOnly? ValidTo            { get; private set; }
    public DateOnly? AcquisitionDate    { get; private set; }
    public decimal?  AcquisitionValue   { get; private set; }

    // ── Referensi eksternal ───────────────────────────────────────
    public string? ExternalRef          { get; private set; }
    public string? TransactionId        { get; private set; } // saga/event correlation ID

    // ── Navigation ────────────────────────────────────────────────
    private readonly List<VehicleMovement> _movements = [];
    public IReadOnlyList<VehicleMovement> Movements => _movements.AsReadOnly();

    private MasterVehicle() { }

    public static MasterVehicle Create(
        string licensePlate,
        string vehicleType,
        string brand,
        string model,
        int year,
        Guid poolLocationId,
        string poolLocationName,
        decimal dailyRate,
        string createdBy,
        string? vin = null,
        string? color = null,
        Guid? vehicleCategoryId = null,
        Guid? transmissionTypeId = null,
        int? numberOfSeats = null,
        string fuelType = "GASOLINE",
        string wheelDrive = "2WD",
        OwnershipType ownershipType = OwnershipType.Own)
    {
        return new MasterVehicle
        {
            Id                = Guid.NewGuid(),
            LicensePlate      = licensePlate.ToUpperInvariant().Replace(" ", ""),
            Vin               = vin,
            VehicleType       = vehicleType.ToUpperInvariant(),
            Brand             = brand,
            Model             = model,
            Year              = year,
            Color             = color,
            VehicleCategoryId = vehicleCategoryId,
            TransmissionTypeId= transmissionTypeId,
            NumberOfSeats     = numberOfSeats,
            FuelType          = fuelType,
            WheelDrive        = wheelDrive,
            Status            = VehicleStatus.Available,
            PoolLocationId    = poolLocationId,
            PoolLocationName  = poolLocationName,
            DailyRate         = dailyRate,
            Odometer          = 0,
            HasObd            = false,
            OwnershipType     = ownershipType,
            CreatedBy         = createdBy,
            CreatedAt         = DateTime.UtcNow,
            IsActive          = true,
            Version           = 1
        };
    }

    // ── State transitions ────────────────────────────────────────

    public void Reserve()
    {
        Status = VehicleStatus.Reserved;
        MarkUpdated();
    }

    public void MarkReady()
    {
        Status = VehicleStatus.Ready;
        MarkUpdated();
    }

    public void SetInUse()
    {
        Status = VehicleStatus.InUse;
        MarkUpdated();
    }

    public void Return(Guid poolLocationId, string poolLocationName)
    {
        Status           = VehicleStatus.Available;
        PoolLocationId   = poolLocationId;
        PoolLocationName = poolLocationName;
        MarkUpdated();
    }

    public void SendToMaintenance(string updatedBy)
    {
        Status = VehicleStatus.Maintenance;
        ConditionInMaintenance = true;
        MarkUpdated(updatedBy);
    }

    public void UpdateOdometer(int newOdometer)
    {
        Odometer = newOdometer;
        MarkUpdated();
    }

    public void UpdatePoolLocation(Guid poolLocationId, string poolLocationName, string updatedBy)
    {
        PoolLocationId   = poolLocationId;
        PoolLocationName = poolLocationName;
        MarkUpdated(updatedBy);
    }

    public void UpdateDailyRate(decimal newRate, string updatedBy)
    {
        DailyRate = newRate;
        MarkUpdated(updatedBy);
    }

    public void SetTransactionId(string transactionId) => TransactionId = transactionId;
}
