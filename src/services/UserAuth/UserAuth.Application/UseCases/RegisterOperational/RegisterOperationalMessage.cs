namespace UserAuth.Application.UseCases.RegisterOperational;

public sealed class RegisterOperationalMessage
{
    public Guid UserId { get; init; }
    public string FullName { get; init; } = default!;
    public DateOnly DateOfBirth { get; init; }
    public string Address { get; init; } = default!;
    public string PhoneNumber { get; init; } = default!;
    public string Email { get; init; } = default!;
    public string PasswordHash { get; init; } = default!;
    public string KtpPhotoPath { get; init; } = default!;
    public string Role { get; init; } = default!;
}
