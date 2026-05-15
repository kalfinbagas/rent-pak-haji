using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Infrastructure.Persistence;
using UserAuth.Application.Abstractions;
using UserAuth.Domain.Entities;
using UserAuth.Infrastructure.Persistence.Configurations;

namespace UserAuth.Infrastructure.Persistence;

public sealed class UserAuthDbContext : BaseDbContext, IUserAuthDbContext
{
    public UserAuthDbContext(DbContextOptions<UserAuthDbContext> options)
        : base(options) { }

    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<OperationalUser> OperationalUsers => Set<OperationalUser>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.ApplyConfiguration(new CustomerConfiguration());
        modelBuilder.ApplyConfiguration(new OperationalUserConfiguration());
    }
}
