using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Application.UseCases.LoginCustomer;

namespace UserAuth.Application.UseCases.LoginOperational;

public sealed record LoginOperationalCommand(
    string Email,
    string Password
) : ICommand<LoginResponse>;
