using FluentValidation;

namespace UserAuth.Application.UseCases.RegisterOperational;

public sealed class RegisterOperationalValidator : AbstractValidator<RegisterOperationalCommand>
{
    public RegisterOperationalValidator()
    {
        RuleFor(x => x.FullName)
            .NotEmpty()
            .MaximumLength(150);

        RuleFor(x => x.DateOfBirth)
            .Must(dob => dob <= DateOnly.FromDateTime(DateTime.UtcNow.AddYears(-17)))
            .WithMessage("User must be at least 17 years old.");

        RuleFor(x => x.Address)
            .NotEmpty()
            .MaximumLength(500);

        RuleFor(x => x.PhoneNumber)
            .NotEmpty()
            .MaximumLength(20)
            .Matches(@"^[0-9+\-\s]+$")
            .WithMessage("PhoneNumber may only contain digits, +, -, and spaces.");

        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(150);

        RuleFor(x => x.Password)
            .NotEmpty()
            .MinimumLength(8);
    }
}
