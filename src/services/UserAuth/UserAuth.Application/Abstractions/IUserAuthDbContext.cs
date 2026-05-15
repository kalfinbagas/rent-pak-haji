using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Domain.Repositories;
using UserAuth.Domain.Entities;

namespace UserAuth.Application.Abstractions;

public interface IUserAuthDbContext : IUnitOfWork
{
    DbSet<Customer> Customers { get; }
    DbSet<OperationalUser> OperationalUsers { get; }
}
