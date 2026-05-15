using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using RentPakHaji.Common.Broker.Abstractions;
using UserAuth.Application.Abstractions;

namespace UserAuth.Application.UseCases.RegisterOperational;

internal sealed class RegisterOperationalHandler
    : ICommandHandler<RegisterOperationalCommand, RegisterOperationalResponse>
{
    private readonly IUserAuthDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IFileStorageService _fileStorage;
    private readonly IRabbitMqPublisher _publisher;

    public RegisterOperationalHandler(
        IUserAuthDbContext db,
        IPasswordHasher hasher,
        IFileStorageService fileStorage,
        IRabbitMqPublisher publisher)
    {
        _db = db;
        _hasher = hasher;
        _fileStorage = fileStorage;
        _publisher = publisher;
    }

    public async Task<Result<RegisterOperationalResponse>> Handle(
        RegisterOperationalCommand request, CancellationToken ct)
    {
        var exists = await _db.OperationalUsers.AnyAsync(u => u.Email == request.Email, ct);
        if (exists)
            return Result.Failure<RegisterOperationalResponse>("DUPLICATE_EMAIL", "Email already registered.");

        var userId = Guid.NewGuid();
        var passwordHash = _hasher.Hash(request.Password);
        var ktpPath = await _fileStorage.SaveFileAsync(request.KtpPhotoStream, request.KtpPhotoFileName, "operational/ktp", ct);

        var message = new RegisterOperationalMessage
        {
            UserId = userId,
            FullName = request.FullName,
            DateOfBirth = request.DateOfBirth,
            Address = request.Address,
            PhoneNumber = request.PhoneNumber,
            Email = request.Email,
            PasswordHash = passwordHash,
            KtpPhotoPath = ktpPath,
            Role = request.Role.ToString(),
        };
        await _publisher.PublishAsync(
            message: message,
            exchange: "userauth",
            routingKey: "userauth.operational.register",
            cancellationToken: ct);

        return Result.Success(new RegisterOperationalResponse(
            userId,
            request.FullName,
            request.Email,
            request.Role.ToString()));
    }
}
