using FluentValidation;

namespace BookingOrder.Application.Usecase.CreateBookingOrder;

public sealed class CreateBookingOrderValidator : AbstractValidator<CreateBookingOrderCommand>
{
    public CreateBookingOrderValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
        RuleFor(x => x.CustomerName).NotEmpty().MaximumLength(150);
        RuleFor(x => x.CustomerPhone).NotEmpty().MaximumLength(20);

        RuleFor(x => x.ServiceType)
            .Must(v => v is "SELF_DRIVE" or "WITH_DRIVER")
            .WithMessage("ServiceType harus SELF_DRIVE atau WITH_DRIVER");

        RuleFor(x => x.VehicleType)
            .Must(v => v is "CAR" or "MOTORCYCLE")
            .WithMessage("VehicleType harus CAR atau MOTORCYCLE");

        RuleFor(x => x.NumberOfVehicles).GreaterThan(0);

        RuleFor(x => x.StartRentalAt)
            .GreaterThan(DateTimeOffset.UtcNow)
            .WithMessage("StartRentalAt tidak boleh backdate");

        RuleFor(x => x.EndRentalAt)
            .GreaterThan(x => x.StartRentalAt)
            .WithMessage("EndRentalAt harus setelah StartRentalAt");

        // Self Drive: durasi harus kelipatan 24 jam, minimal 1 hari
        When(x => x.ServiceType == "SELF_DRIVE", () =>
        {
            RuleFor(x => x.DurationDays)
                .NotNull()
                .GreaterThanOrEqualTo(1)
                .WithMessage("Self Drive: minimal 1 hari (kelipatan 24 jam)");

            RuleFor(x => x)
                .Must(x =>
                {
                    var diff = (x.EndRentalAt - x.StartRentalAt).TotalHours;
                    return diff % 24 == 0 && diff >= 24;
                })
                .WithMessage("Self Drive: durasi harus kelipatan 24 jam, minimal 1 hari");
        });

        // With Driver: harus ada WithDriverDurationHours yang valid
        When(x => x.ServiceType == "WITH_DRIVER", () =>
        {
            RuleFor(x => x.WithDriverDurationHours)
                .NotNull()
                .Must(h => h is 4 or 6 or 8 or 12 or 16)
                .WithMessage("With Driver: durasi harus 4, 6, 8, 12, atau 16 jam");
        });

        RuleFor(x => x.DailyRate).GreaterThan(0);
        RuleFor(x => x.IdempotencyKey).NotEmpty().MaximumLength(100);

        RuleFor(x => x.StartPoolLocationId).NotEmpty();
        RuleFor(x => x.StartPoolLocationName).NotEmpty();
        RuleFor(x => x.EndPoolLocationId).NotEmpty();
        RuleFor(x => x.EndPoolLocationName).NotEmpty();

        When(x => x.StartExpeditionType == "EXPEDITION", () =>
        {
            RuleFor(x => x.StartAddress).NotEmpty().WithMessage("Alamat wajib diisi untuk tipe EXPEDITION");
            RuleFor(x => x.StartCity).NotEmpty();
        });

        When(x => x.EndExpeditionType == "EXPEDITION", () =>
        {
            RuleFor(x => x.EndAddress).NotEmpty().WithMessage("Alamat wajib diisi untuk tipe EXPEDITION");
            RuleFor(x => x.EndCity).NotEmpty();
        });
    }
}
