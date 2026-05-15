namespace UserAuth.Application.UseCases.VerifyCustomer;

public sealed class VerifyCustomerMessage
{
    public Guid CustomerId { get; init; }
}
