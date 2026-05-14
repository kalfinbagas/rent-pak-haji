using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using RentPakHaji.Common.Infrastructure.Persistence;
using Vehicle.Application.Abstractions;
using Vehicle.Domain.Entities;
using Vehicle.Infrastructure.Persistence.Configurations;

namespace Vehicle.Infrastructure.Persistence;

public sealed class VehicleDbContext : BaseDbContext, IVehicleDbContext
{
    public VehicleDbContext(DbContextOptions<VehicleDbContext> options) : base(options) { }

    public DbSet<VehicleCategory>           VehicleCategories   { get; set; } = null!;
    public DbSet<VehicleTransmissionType>   TransmissionTypes   { get; set; } = null!;
    public DbSet<MasterVehicle>             MasterVehicles      { get; set; } = null!;
    public DbSet<VehicleMovement>           VehicleMovements    { get; set; } = null!;
    public DbSet<VehiclePreparation>        VehiclePreparations { get; set; } = null!;
    public DbSet<VehicleSoftBookingReplica> VehicleSoftBookings { get; set; } = null!;
    public DbSet<VehicleAssignmentReplica>  VehicleAssignments  { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.ApplyConfiguration(new VehicleCategoryConfiguration());
        modelBuilder.ApplyConfiguration(new VehicleTransmissionTypeConfiguration());
        modelBuilder.ApplyConfiguration(new MasterVehicleConfiguration());
        modelBuilder.ApplyConfiguration(new VehicleMovementConfiguration());
        modelBuilder.ApplyConfiguration(new VehiclePreparationConfiguration());
        modelBuilder.ApplyConfiguration(new VehicleSoftBookingReplicaConfiguration());
        modelBuilder.ApplyConfiguration(new VehicleAssignmentReplicaConfiguration());
    }
}
