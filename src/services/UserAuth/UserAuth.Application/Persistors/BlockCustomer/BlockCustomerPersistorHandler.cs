using MediatR;
using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Application.Abstractions;

namespace UserAuth.Application.Persistors.BlockCustomer;

internal sealed class BlockCustomerPersistorHandler
    : ICommandHandler<BlockCustomerPersistorCommand, Unit>
{
    private readonly IUserAuthDbContext _db;
    public BlockCustomerPersistorHandler(IUserAuthDbContext db) { _db = db; }

    public async Task<Result<Unit>> Handle(BlockCustomerPersistorCommand request, CancellationToken ct)
    {
        var customer = await _db.Customers
            .FirstOrDefaultAsync(c => c.Id == request.CustomerId, ct);

        if (customer is null)
            return Result.Failure<Unit>("NOT_FOUND", $"Customer {request.CustomerId} not found.");

        customer.Block();
        await _db.SaveChangesAsync(ct);
        return Result.Success(Unit.Value);
    }
}
