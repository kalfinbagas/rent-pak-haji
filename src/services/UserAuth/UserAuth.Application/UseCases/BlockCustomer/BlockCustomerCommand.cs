using RentPakHaji.Common.Application.Abstractions;

namespace UserAuth.Application.UseCases.BlockCustomer;

public sealed record BlockCustomerCommand(Guid CustomerId) : ICommand;
