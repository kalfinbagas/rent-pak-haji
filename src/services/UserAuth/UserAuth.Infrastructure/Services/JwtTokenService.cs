using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using UserAuth.Application.Abstractions;

namespace UserAuth.Infrastructure.Services;

public sealed class JwtTokenService : IJwtTokenService
{
    private readonly IConfiguration _config;

    public JwtTokenService(IConfiguration config) => _config = config;

    public string GenerateToken(Guid userId, string email, string role, string userType)
    {
        var key    = _config["Jwt:Key"] ?? throw new InvalidOperationException("Jwt:Key is not configured.");
        var issuer = _config["Jwt:Issuer"]   ?? "rent-pak-haji";
        var aud    = _config["Jwt:Audience"] ?? "rent-pak-haji-clients";

        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));
        var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

        var now    = DateTimeOffset.UtcNow;
        var expiry = now.AddSeconds(86400);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub,   userId.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, email),
            new Claim(JwtRegisteredClaimNames.Iat,   now.ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64),
            new Claim("role",     role),
            new Claim("userType", userType),
        };

        var token = new JwtSecurityToken(
            issuer:            issuer,
            audience:          aud,
            claims:            claims,
            notBefore:         now.UtcDateTime,
            expires:           expiry.UtcDateTime,
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
