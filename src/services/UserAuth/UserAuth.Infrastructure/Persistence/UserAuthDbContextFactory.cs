using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace UserAuth.Infrastructure.Persistence;

/// <summary>
/// Design-time factory for EF Tools.
///
/// Usage (from src/services/UserAuth/):
///   dotnet ef migrations add InitialCreate --project UserAuth.Infrastructure
///   dotnet ef database update              --project UserAuth.Infrastructure
///
/// Override connection string via env var:
///   set ConnectionStrings__UserAuthDb=Host=...
/// </summary>
public sealed class UserAuthDbContextFactory
    : IDesignTimeDbContextFactory<UserAuthDbContext>
{
    public UserAuthDbContext CreateDbContext(string[] args)
    {
        var connectionString =
            Environment.GetEnvironmentVariable("ConnectionStrings__UserAuthDb")
            ?? "Host=localhost;Port=5433;Database=rpk_identity;Username=rpk_admin;Password=RpkSecure2026!";

        var optionsBuilder = new DbContextOptionsBuilder<UserAuthDbContext>();
        optionsBuilder.UseNpgsql(
            connectionString,
            npgsql => npgsql.MigrationsAssembly(typeof(UserAuthDbContext).Assembly.FullName));

        return new UserAuthDbContext(optionsBuilder.Options);
    }
}
