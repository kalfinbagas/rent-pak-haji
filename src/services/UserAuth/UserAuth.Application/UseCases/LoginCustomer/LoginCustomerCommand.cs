using RentPakHaji.Common.Application.Abstractions;

namespace UserAuth.Application.UseCases.LoginCustomer;

public sealed record LoginCustomerCommand(
    string Email,
    string Password
) : ICommand<LoginResponse>;
