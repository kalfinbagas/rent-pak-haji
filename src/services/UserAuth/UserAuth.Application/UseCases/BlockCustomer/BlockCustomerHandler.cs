using RentPakHaji.Common.Application;
using RentPakHaji.Common.Application.Abstractions;
using RentPakHaji.Common.Broker.Abstractions;

namespace UserAuth.Application.UseCases.BlockCustomer;

internal sealed class BlockCustomerHandler : ICommandHandler<BlockCustomerCommand>
{
    private readonly IRabbitMqPublisher _publisher;
    public BlockCustomerHandler(IRabbitMqPublisher publisher) { _publisher = publisher; }

    public async Task<Result> Handle(BlockCustomerCommand request, CancellationToken ct)
    {
        await _publisher.PublishAsync(
            message: new BlockCustomerMessage { CustomerId = request.CustomerId },
            exchange: "userauth",
            routingKey: "userauth.customer.block",
            cancellationToken: ct);
        return Result.Success();
    }
}
