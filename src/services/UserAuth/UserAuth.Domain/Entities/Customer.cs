using RentPakHaji.Common.Domain.Primitives;
using UserAuth.Domain.Enums;

namespace UserAuth.Domain.Entities;

public sealed class Customer : AuditableEntity
{
    public string FullName { get; private set; } = default!;
    public DateOnly DateOfBirth { get; private set; }
    public string Address { get; private set; } = default!;
    public string PhoneNumber { get; private set; } = default!;
    public string Email { get; private set; } = default!;
    public string PasswordHash { get; private set; } = default!;
    public string KtpPhotoPath { get; private set; } = default!;
    public string? SimAPhotoPath { get; private set; }
    public CustomerStatus Status { get; private set; } = CustomerStatus.Unverified;

    // EF Core ctor
    private Customer() { }

    public static Customer Create(
        string fullName,
        DateOnly dateOfBirth,
        string address,
        string phoneNumber,
        string email,
        string passwordHash,
        string ktpPhotoPath,
        string? simAPhotoPath = null)
    {
        return new Customer
        {
            FullName      = fullName,
            DateOfBirth   = dateOfBirth,
            Address       = address,
            PhoneNumber   = phoneNumber,
            Email         = email,
            PasswordHash  = passwordHash,
            KtpPhotoPath  = ktpPhotoPath,
            SimAPhotoPath = simAPhotoPath,
            Status        = CustomerStatus.Unverified,
        };
    }

    public static Customer CreateWithId(
        Guid id,
        string fullName,
        DateOnly dateOfBirth,
        string address,
        string phoneNumber,
        string email,
        string passwordHash,
        string ktpPhotoPath,
        string? simAPhotoPath = null)
    {
        var customer = Create(fullName, dateOfBirth, address, phoneNumber, email, passwordHash, ktpPhotoPath, simAPhotoPath);
        customer.Id = id;
        return customer;
    }

    public void Verify()
    {
        Status = CustomerStatus.Verified;
        MarkUpdated();
    }

    public void Block()
    {
        Status = CustomerStatus.Blocked;
        MarkUpdated();
    }

    public void Unblock()
    {
        Status = CustomerStatus.Unverified;
        MarkUpdated();
    }

    public void UpdatePassword(string newPasswordHash)
    {
        PasswordHash = newPasswordHash;
        MarkUpdated();
    }
}
