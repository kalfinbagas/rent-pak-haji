using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Domain.Repositories;
using Vehicle.Domain.Entities;

namespace Vehicle.Application.Abstractions;

public interface IVehicleDbContext : IUnitOfWork
{
    DbSet<VehicleCategory>            VehicleCategories            { get; }
    DbSet<VehicleTransmissionType>    TransmissionTypes            { get; }
    DbSet<MasterVehicle>              MasterVehicles               { get; }
    DbSet<VehicleMovement>            VehicleMovements             { get; }
    DbSet<VehiclePreparation>         VehiclePreparations          { get; }
    DbSet<VehicleSoftBookingReplica>  VehicleSoftBookings          { get; }
    DbSet<VehicleAssignmentReplica>   VehicleAssignments           { get; }
}
