using MediatR;
using RentPakHaji.Common.Application.Abstractions;

namespace UserAuth.Application.Persistors.VerifyCustomer;

public sealed class VerifyCustomerPersistorCommand : ICommand<Unit>
{
    public Guid CustomerId { get; init; }
}
