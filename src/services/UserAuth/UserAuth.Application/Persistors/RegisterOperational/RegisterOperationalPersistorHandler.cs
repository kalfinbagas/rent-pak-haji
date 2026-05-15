using MediatR;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Application.Abstractions;
using UserAuth.Domain.Entities;

namespace UserAuth.Application.Persistors.RegisterOperational;

internal sealed class RegisterOperationalPersistorHandler
    : ICommandHandler<RegisterOperationalPersistorCommand, Unit>
{
    private readonly IUserAuthDbContext _db;
    public RegisterOperationalPersistorHandler(IUserAuthDbContext db) { _db = db; }

    public async Task<Result<Unit>> Handle(RegisterOperationalPersistorCommand request, CancellationToken ct)
    {
        var user = OperationalUser.CreateWithId(
            id: request.UserId,
            fullName: request.FullName,
            dateOfBirth: request.DateOfBirth,
            address: request.Address,
            phoneNumber: request.PhoneNumber,
            email: request.Email,
            passwordHash: request.PasswordHash,
            ktpPhotoPath: request.KtpPhotoPath,
            role: request.Role);

        await _db.OperationalUsers.AddAsync(user, ct);
        await _db.SaveChangesAsync(ct);
        return Result.Success(Unit.Value);
    }
}
