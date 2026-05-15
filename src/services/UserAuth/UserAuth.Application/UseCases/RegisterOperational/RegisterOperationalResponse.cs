namespace UserAuth.Application.UseCases.RegisterOperational;

public sealed record RegisterOperationalResponse(
    Guid UserId,
    string FullName,
    string Email,
    string Role
);
