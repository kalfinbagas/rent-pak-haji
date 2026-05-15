namespace UserAuth.Application.UseCases.GetCustomerById;

public sealed record CustomerDetailResponse(
    Guid Id,
    string FullName,
    DateOnly DateOfBirth,
    string Address,
    string PhoneNumber,
    string Email,
    string KtpPhotoPath,
    string? SimAPhotoPath,
    string Status,
    DateTime CreatedAt,
    DateTime? UpdatedAt
);
