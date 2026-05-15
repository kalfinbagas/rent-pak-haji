using RentPakHaji.Common.Application.Abstractions;
using UserAuth.Domain.Enums;

namespace UserAuth.Application.UseCases.RegisterOperational;

public sealed record RegisterOperationalCommand(
    string FullName,
    DateOnly DateOfBirth,
    string Address,
    string PhoneNumber,
    string Email,
    string Password,
    OperationalRole Role,
    Stream KtpPhotoStream,
    string KtpPhotoFileName
) : ICommand<RegisterOperationalResponse>;
