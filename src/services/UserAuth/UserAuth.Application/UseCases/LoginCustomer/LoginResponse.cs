namespace UserAuth.Application.UseCases.LoginCustomer;

public sealed record LoginResponse(
    string Token,
    DateTimeOffset ExpiresAt,
    Guid UserId,
    string Email,
    string Role,
    string UserType
);
