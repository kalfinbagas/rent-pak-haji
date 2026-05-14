using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Application.Abstractions;

namespace BookingOrder.Application.Abstractions;

public interface IBookingOrderDbContext : IUnitOfWork
{
    DbSet<Domain.Entities.BookingOrder> BookingOrders { get; }
    DbSet<Domain.Entities.BookingOrderDetail> BookingOrderDetails { get; }
    DbSet<Domain.Entities.VehicleSoftBooking> VehicleSoftBookings { get; }
    DbSet<Domain.Entities.VehicleAssignment> VehicleAssignments { get; }
}
