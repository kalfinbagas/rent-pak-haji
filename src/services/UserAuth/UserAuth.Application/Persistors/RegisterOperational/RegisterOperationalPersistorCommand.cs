using MediatR;
using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Domain.Enums;

namespace UserAuth.Application.Persistors.RegisterOperational;

public sealed class RegisterOperationalPersistorCommand : ICommand<Unit>
{
    public Guid UserId { get; init; }
    public string FullName { get; init; } = default!;
    public DateOnly DateOfBirth { get; init; }
    public string Address { get; init; } = default!;
    public string PhoneNumber { get; init; } = default!;
    public string Email { get; init; } = default!;
    public string PasswordHash { get; init; } = default!;
    public string KtpPhotoPath { get; init; } = default!;
    public OperationalRole Role { get; init; }
}
