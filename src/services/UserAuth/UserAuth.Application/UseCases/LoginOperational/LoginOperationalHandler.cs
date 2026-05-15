using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Application.Abstractions;
using UserAuth.Application.UseCases.LoginCustomer;

namespace UserAuth.Application.UseCases.LoginOperational;

public sealed class LoginOperationalHandler
    : ICommandHandler<LoginOperationalCommand, LoginResponse>
{
    private readonly IUserAuthDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IJwtTokenService _jwt;

    public LoginOperationalHandler(
        IUserAuthDbContext db,
        IPasswordHasher hasher,
        IJwtTokenService jwt)
    {
        _db     = db;
        _hasher = hasher;
        _jwt    = jwt;
    }

    public async Task<Result<LoginResponse>> Handle(
        LoginOperationalCommand cmd,
        CancellationToken cancellationToken)
    {
        var user = await _db.OperationalUsers
            .FirstOrDefaultAsync(u => u.Email == cmd.Email, cancellationToken);

        if (user is null)
            return Result.Failure<LoginResponse>("INVALID_CREDENTIALS", "Invalid email or password.");

        if (!_hasher.Verify(cmd.Password, user.PasswordHash))
            return Result.Failure<LoginResponse>("INVALID_CREDENTIALS", "Invalid email or password.");

        var token    = _jwt.GenerateToken(user.Id, user.Email, user.Role.ToString(), "Operational");
        var expiresAt = DateTimeOffset.UtcNow.AddSeconds(86400);

        return Result.Success(new LoginResponse(
            token,
            expiresAt,
            user.Id,
            user.Email,
            user.Role.ToString(),
            "Operational"));
    }
}
