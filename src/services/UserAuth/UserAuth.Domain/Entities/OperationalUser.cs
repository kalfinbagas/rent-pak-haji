using RentPakHaji.Common.Domain.Primitives;
using UserAuth.Domain.Enums;

namespace UserAuth.Domain.Entities;

public sealed class OperationalUser : AuditableEntity
{
    public string FullName { get; private set; } = default!;
    public DateOnly DateOfBirth { get; private set; }
    public string Address { get; private set; } = default!;
    public string PhoneNumber { get; private set; } = default!;
    public string Email { get; private set; } = default!;
    public string PasswordHash { get; private set; } = default!;
    public string KtpPhotoPath { get; private set; } = default!;
    public OperationalRole Role { get; private set; }

    // EF Core ctor
    private OperationalUser() { }

    public static OperationalUser Create(
        string fullName,
        DateOnly dateOfBirth,
        string address,
        string phoneNumber,
        string email,
        string passwordHash,
        string ktpPhotoPath,
        OperationalRole role)
    {
        return new OperationalUser
        {
            FullName     = fullName,
            DateOfBirth  = dateOfBirth,
            Address      = address,
            PhoneNumber  = phoneNumber,
            Email        = email,
            PasswordHash = passwordHash,
            KtpPhotoPath = ktpPhotoPath,
            Role         = role,
        };
    }

    public static OperationalUser CreateWithId(
        Guid id,
        string fullName,
        DateOnly dateOfBirth,
        string address,
        string phoneNumber,
        string email,
        string passwordHash,
        string ktpPhotoPath,
        OperationalRole role)
    {
        var user = Create(fullName, dateOfBirth, address, phoneNumber, email, passwordHash, ktpPhotoPath, role);
        user.Id = id;
        return user;
    }

    public void UpdatePassword(string newPasswordHash)
    {
        PasswordHash = newPasswordHash;
        MarkUpdated();
    }
}
