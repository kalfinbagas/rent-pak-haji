namespace UserAuth.Application.UseCases.BlockCustomer;

public sealed class BlockCustomerMessage
{
    public Guid CustomerId { get; init; }
}
