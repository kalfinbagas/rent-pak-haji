using MediatR;
using RentPakHaji.Common.Application.Abstractions;

namespace UserAuth.Application.Persistors.BlockCustomer;

public sealed class BlockCustomerPersistorCommand : ICommand<Unit>
{
    public Guid CustomerId { get; init; }
}
