namespace UserAuth.Application.UseCases.RegisterCustomer;

public sealed class RegisterCustomerMessage
{
    public Guid CustomerId { get; init; }
    public string FullName { get; init; } = default!;
    public DateOnly DateOfBirth { get; init; }
    public string Address { get; init; } = default!;
    public string PhoneNumber { get; init; } = default!;
    public string Email { get; init; } = default!;
    public string PasswordHash { get; init; } = default!;
    public string KtpPhotoPath { get; init; } = default!;
    public string? SimAPhotoPath { get; init; }
}
