using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using RentPakHaji.Common.Broker.Abstractions;

namespace UserAuth.Application.UseCases.VerifyCustomer;

internal sealed class VerifyCustomerHandler : ICommandHandler<VerifyCustomerCommand>
{
    private readonly IRabbitMqPublisher _publisher;
    public VerifyCustomerHandler(IRabbitMqPublisher publisher) { _publisher = publisher; }

    public async Task<Result> Handle(VerifyCustomerCommand request, CancellationToken ct)
    {
        await _publisher.PublishAsync(
            message: new VerifyCustomerMessage { CustomerId = request.CustomerId },
            exchange: "userauth",
            routingKey: "userauth.customer.verify",
            cancellationToken: ct);
        return Result.Success();
    }
}
