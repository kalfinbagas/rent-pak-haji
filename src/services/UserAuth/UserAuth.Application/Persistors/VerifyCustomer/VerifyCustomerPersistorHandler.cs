using MediatR;
using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Application.Abstractions;

namespace UserAuth.Application.Persistors.VerifyCustomer;

internal sealed class VerifyCustomerPersistorHandler
    : ICommandHandler<VerifyCustomerPersistorCommand, Unit>
{
    private readonly IUserAuthDbContext _db;
    public VerifyCustomerPersistorHandler(IUserAuthDbContext db) { _db = db; }

    public async Task<Result<Unit>> Handle(VerifyCustomerPersistorCommand request, CancellationToken ct)
    {
        var customer = await _db.Customers
            .FirstOrDefaultAsync(c => c.Id == request.CustomerId, ct);

        if (customer is null)
            return Result.Failure<Unit>("NOT_FOUND", $"Customer {request.CustomerId} not found.");

        customer.Verify();
        await _db.SaveChangesAsync(ct);
        return Result.Success(Unit.Value);
    }
}
