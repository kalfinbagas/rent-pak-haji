namespace UserAuth.Application.Abstractions;

public interface IJwtTokenService
{
    string GenerateToken(Guid userId, string email, string role, string userType);
}
