using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using RentPakHaji.Common.Broker.Abstractions;
using UserAuth.Application.Abstractions;

namespace UserAuth.Application.UseCases.RegisterCustomer;

internal sealed class RegisterCustomerHandler
    : ICommandHandler<RegisterCustomerCommand, RegisterCustomerResponse>
{
    private readonly IUserAuthDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IFileStorageService _fileStorage;
    private readonly IRabbitMqPublisher _publisher;

    public RegisterCustomerHandler(
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

    public async Task<Result<RegisterCustomerResponse>> Handle(
        RegisterCustomerCommand request, CancellationToken ct)
    {
        // Check duplicate email
        var exists = await _db.Customers.AnyAsync(c => c.Email == request.Email, ct);
        if (exists)
            return Result.Failure<RegisterCustomerResponse>("DUPLICATE_EMAIL", "Email already registered.");

        var customerId = Guid.NewGuid();
        var passwordHash = _hasher.Hash(request.Password);

        // Save photos
        var ktpPath = await _fileStorage.SaveFileAsync(request.KtpPhotoStream, request.KtpPhotoFileName, "customers/ktp", ct);
        string? simPath = null;
        if (request.SimAPhotoStream is not null && request.SimAPhotoFileName is not null)
            simPath = await _fileStorage.SaveFileAsync(request.SimAPhotoStream, request.SimAPhotoFileName, "customers/sim", ct);

        // Publish to broker — Worker will persist
        var message = new RegisterCustomerMessage
        {
            CustomerId = customerId,
            FullName = request.FullName,
            DateOfBirth = request.DateOfBirth,
            Address = request.Address,
            PhoneNumber = request.PhoneNumber,
            Email = request.Email,
            PasswordHash = passwordHash,
            KtpPhotoPath = ktpPath,
            SimAPhotoPath = simPath,
        };
        await _publisher.PublishAsync(
            message: message,
            exchange: "userauth",
            routingKey: "userauth.customer.register",
            cancellationToken: ct);

        return Result.Success(new RegisterCustomerResponse(
            customerId,
            request.FullName,
            request.Email,
            "Unverified"));
    }
}
