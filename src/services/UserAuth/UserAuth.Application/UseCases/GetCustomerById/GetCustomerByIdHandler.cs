using Microsoft.EntityFrameworkCore;
using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Application.Abstractions;

namespace UserAuth.Application.UseCases.GetCustomerById;

public sealed class GetCustomerByIdHandler : IQueryHandler<GetCustomerByIdQuery, CustomerDetailResponse>
{
    private readonly IUserAuthDbContext _db;

    public GetCustomerByIdHandler(IUserAuthDbContext db) => _db = db;

    public async Task<Result<CustomerDetailResponse>> Handle(
        GetCustomerByIdQuery query,
        CancellationToken cancellationToken)
    {
        var customer = await _db.Customers
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == query.CustomerId, cancellationToken);

        if (customer is null)
            return Result.Failure<CustomerDetailResponse>("NOT_FOUND", "Customer not found.");

        return Result.Success(new CustomerDetailResponse(
            customer.Id,
            customer.FullName,
            customer.DateOfBirth,
            customer.Address,
            customer.PhoneNumber,
            customer.Email,
            customer.KtpPhotoPath,
            customer.SimAPhotoPath,
            customer.Status.ToString(),
            customer.CreatedAt,
            customer.UpdatedAt));
    }
}
