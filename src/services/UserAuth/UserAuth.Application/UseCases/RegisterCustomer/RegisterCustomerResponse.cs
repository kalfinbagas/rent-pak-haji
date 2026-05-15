namespace UserAuth.Application.UseCases.RegisterCustomer;

public sealed record RegisterCustomerResponse(
    Guid CustomerId,
    string FullName,
    string Email,
    string Status
);
