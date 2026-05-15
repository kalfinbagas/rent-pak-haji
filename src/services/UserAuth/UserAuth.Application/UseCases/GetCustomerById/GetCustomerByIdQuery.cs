using RentPakHaji.Common.Application.Abstractions;

namespace UserAuth.Application.UseCases.GetCustomerById;

public sealed record GetCustomerByIdQuery(Guid CustomerId) : IQuery<CustomerDetailResponse>;
