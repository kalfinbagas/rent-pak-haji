using BookingOrder.Application.Abstractions;
using BookingOrder.Domain.Entities;
using BookingOrder.Infrastructure.Persistence.Configurations;
using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Infrastructure.Persistence;

namespace BookingOrder.Infrastructure.Persistence;

public sealed class BookingOrderDbContext : BaseDbContext, IBookingOrderDbContext
{
    public BookingOrderDbContext(DbContextOptions<BookingOrderDbContext> options)
        : base(options) { }

    public DbSet<Domain.Entities.BookingOrder> BookingOrders => Set<Domain.Entities.BookingOrder>();
    public DbSet<BookingOrderDetail> BookingOrderDetails => Set<BookingOrderDetail>();
    public DbSet<VehicleSoftBooking> VehicleSoftBookings => Set<VehicleSoftBooking>();
    public DbSet<VehicleAssignment> VehicleAssignments => Set<VehicleAssignment>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.ApplyConfiguration(new BookingOrderConfiguration());
        modelBuilder.ApplyConfiguration(new BookingOrderDetailConfiguration());
        modelBuilder.ApplyConfiguration(new VehicleSoftBookingConfiguration());
        modelBuilder.ApplyConfiguration(new VehicleAssignmentConfiguration());
    }
}
