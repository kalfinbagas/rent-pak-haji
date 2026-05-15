using RentPakHaji.Common.Application.Abstractions;

namespace UserAuth.Application.UseCases.RegisterCustomer;

public sealed record RegisterCustomerCommand(
    string FullName,
    DateOnly DateOfBirth,
    string Address,
    string PhoneNumber,
    string Email,
    string Password,
    Stream KtpPhotoStream,
    string KtpPhotoFileName,
    Stream? SimAPhotoStream,
    string? SimAPhotoFileName
) : ICommand<RegisterCustomerResponse>;
