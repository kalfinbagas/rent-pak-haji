using FluentValidation;

namespace UserAuth.Application.UseCases.LoginOperational;

public sealed class LoginOperationalValidator : AbstractValidator<LoginOperationalCommand>
{
    public LoginOperationalValidator()
    {
        RuleFor(x => x.Email).NotEmpty();
        RuleFor(x => x.Password).NotEmpty();
    }
}
