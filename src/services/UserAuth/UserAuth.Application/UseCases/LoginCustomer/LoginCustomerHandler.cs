using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Application.Abstractions;
using UserAuth.Domain.Enums;

namespace UserAuth.Application.UseCases.LoginCustomer;

public sealed class LoginCustomerHandler
    : ICommandHandler<LoginCustomerCommand, LoginResponse>
{
    private readonly IUserAuthDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IJwtTokenService _jwt;

    public LoginCustomerHandler(
        IUserAuthDbContext db,
        IPasswordHasher hasher,
        IJwtTokenService jwt)
    {
        _db     = db;
        _hasher = hasher;
        _jwt    = jwt;
    }

    public async Task<Result<LoginResponse>> Handle(
        LoginCustomerCommand cmd,
        CancellationToken cancellationToken)
    {
        var customer = await _db.Customers
            .FirstOrDefaultAsync(c => c.Email == cmd.Email, cancellationToken);

        if (customer is null || customer.Status == CustomerStatus.Blocked)
            return Result.Failure<LoginResponse>("INVALID_CREDENTIALS", "Invalid email or password.");

        if (!_hasher.Verify(cmd.Password, customer.PasswordHash))
            return Result.Failure<LoginResponse>("INVALID_CREDENTIALS", "Invalid email or password.");

        var token    = _jwt.GenerateToken(customer.Id, customer.Email, customer.Status.ToString(), "Customer");
        var expiresAt = DateTimeOffset.UtcNow.AddSeconds(86400);

        return Result.Success(new LoginResponse(
            token,
            expiresAt,
            customer.Id,
            customer.Email,
            customer.Status.ToString(),
            "Customer"));
    }
}
