using MediatR;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Application.Abstractions;
using UserAuth.Domain.Entities;

namespace UserAuth.Application.Persistors.RegisterCustomer;

internal sealed class RegisterCustomerPersistorHandler
    : ICommandHandler<RegisterCustomerPersistorCommand, Unit>
{
    private readonly IUserAuthDbContext _db;
    public RegisterCustomerPersistorHandler(IUserAuthDbContext db) { _db = db; }

    public async Task<Result<Unit>> Handle(RegisterCustomerPersistorCommand request, CancellationToken ct)
    {
        var customer = Customer.CreateWithId(
            id: request.CustomerId,
            fullName: request.FullName,
            dateOfBirth: request.DateOfBirth,
            address: request.Address,
            phoneNumber: request.PhoneNumber,
            email: request.Email,
            passwordHash: request.PasswordHash,
            ktpPhotoPath: request.KtpPhotoPath,
            simAPhotoPath: request.SimAPhotoPath);

        await _db.Customers.AddAsync(customer, ct);
        await _db.SaveChangesAsync(ct);
        return Result.Success(Unit.Value);
    }
}
