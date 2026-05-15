using FluentValidation;

namespace UserAuth.Application.UseCases.LoginCustomer;

public sealed class LoginCustomerValidator : AbstractValidator<LoginCustomerCommand>
{
    public LoginCustomerValidator()
    {
        RuleFor(x => x.Email).NotEmpty();
        RuleFor(x => x.Password).NotEmpty();
    }
}
