using RentPakHaji.Common.Application.Abstractions;

namespace UserAuth.Application.UseCases.VerifyCustomer;

public sealed record VerifyCustomerCommand(Guid CustomerId) : ICommand;
