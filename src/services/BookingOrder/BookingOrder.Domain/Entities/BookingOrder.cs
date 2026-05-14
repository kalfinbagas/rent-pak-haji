using RentPakHaji.Common.Domain.Primitives;

namespace BookingOrder.Domain.Entities;

public sealed class BookingOrder : AuditableEntity
{
    // ─── Identity ──────────────────────────────────────────────
    public string BookingCode { get; private set; } = default!;     // RPK-YYYYMMDD-XXXX
    public BookingStatus Status { get; private set; } = BookingStatus.AwaitingPayment;

    // ─── Customer (snapshot) ───────────────────────────────────
    public Guid CustomerId { get; private set; }
    public string CustomerName { get; private set; } = default!;
    public string CustomerPhone { get; private set; } = default!;
    public string? CustomerEmail { get; private set; }

    // ─── Service ───────────────────────────────────────────────
    public ServiceType ServiceType { get; private set; }

    // ─── Vehicle request ───────────────────────────────────────
    public string VehicleType { get; private set; } = default!;     // CAR / MOTORCYCLE
    public string? VehicleCategory { get; private set; }            // MPV, SUV, dll
    public int NumberOfVehicles { get; private set; } = 1;

    // ─── Rental window ─────────────────────────────────────────
    public DateTimeOffset StartRentalAt { get; private set; }
    public DateTimeOffset EndRentalAt { get; private set; }
    public int? DurationDays { get; private set; }                  // null if WITH_DRIVER hourly

    // ─── With Driver extras ────────────────────────────────────
    public int? WithDriverDurationHours { get; private set; }       // 4/6/8/12/16 jam
    public bool IsOutOfTown { get; private set; }

    // ─── Pricing snapshot ──────────────────────────────────────
    public decimal DailyRate { get; private set; }
    public decimal SubtotalRental { get; private set; }
    public decimal SubtotalAmount { get; private set; }
    public decimal TaxAmount { get; private set; }
    public decimal TotalAmount { get; private set; }

    // ─── Voucher ───────────────────────────────────────────────
    public string? VoucherCode { get; private set; }
    public decimal VoucherDiscount { get; private set; }
    public bool HasSpecialPrice { get; private set; }

    // ─── Assigned vehicle (filled at dispatch) ─────────────────
    public Guid? AssignedVehicleId { get; private set; }
    public string? VehicleRegistrationNumber { get; private set; }
    public string? VehicleBrand { get; private set; }
    public string? VehicleModel { get; private set; }
    public string? VehicleColor { get; private set; }

    // ─── Assigned driver (filled at dispatch, with_driver only) ─
    public Guid? AssignedDriverId { get; private set; }
    public string? DriverName { get; private set; }
    public string? DriverPhone { get; private set; }

    // ─── Payment window ────────────────────────────────────────
    public string IdempotencyKey { get; private set; } = default!;
    public string TransactionId { get; private set; } = default!;   // saga correlation
    public DateTimeOffset PaymentExpiresAt { get; private set; }

    // ─── Timestamps ────────────────────────────────────────────
    public DateTimeOffset? PaidAt { get; private set; }
    public DateTimeOffset? ConfirmedAt { get; private set; }
    public DateTimeOffset? CompletedAt { get; private set; }
    public DateTimeOffset? ExpiredAt { get; private set; }
    public DateTimeOffset? CancelledAt { get; private set; }
    public string? CancellationReason { get; private set; }
    public string? OperatorNotes { get; private set; }

    // ─── Navigation ────────────────────────────────────────────
    private readonly List<BookingOrderDetail> _details = [];
    public IReadOnlyList<BookingOrderDetail> Details => _details.AsReadOnly();

    private readonly List<VehicleSoftBooking> _softBookings = [];
    public IReadOnlyList<VehicleSoftBooking> SoftBookings => _softBookings.AsReadOnly();

    private readonly List<VehicleAssignment> _assignments = [];
    public IReadOnlyList<VehicleAssignment> Assignments => _assignments.AsReadOnly();

    // ─── EF Core ctor ──────────────────────────────────────────
    private BookingOrder() { }

    // ─── Factories ─────────────────────────────────────────────

    /// <summary>
    /// Create with a pre-assigned ID (used by the message-consumer
    /// which receives the ID that the API handler pre-generated).
    /// </summary>
    public static BookingOrder CreateWithId(
        Guid id,
        string bookingCode,
        Guid customerId,
        string customerName,
        string customerPhone,
        string? customerEmail,
        ServiceType serviceType,
        string vehicleType,
        string? vehicleCategory,
        int numberOfVehicles,
        DateTimeOffset startRentalAt,
        DateTimeOffset endRentalAt,
        int? durationDays,
        int? withDriverDurationHours,
        bool isOutOfTown,
        decimal dailyRate,
        decimal subtotalRental,
        decimal subtotalAmount,
        decimal taxAmount,
        decimal totalAmount,
        string idempotencyKey,
        string transactionId,
        DateTimeOffset paymentExpiresAt)
    {
        var order = Create(
            bookingCode, customerId, customerName, customerPhone, customerEmail,
            serviceType, vehicleType, vehicleCategory, numberOfVehicles,
            startRentalAt, endRentalAt, durationDays, withDriverDurationHours,
            isOutOfTown, dailyRate, subtotalRental, subtotalAmount,
            taxAmount, totalAmount, idempotencyKey, transactionId, paymentExpiresAt);
        order.Id = id;
        return order;
    }

    public static BookingOrder Create(
        string bookingCode,
        Guid customerId,
        string customerName,
        string customerPhone,
        string? customerEmail,
        ServiceType serviceType,
        string vehicleType,
        string? vehicleCategory,
        int numberOfVehicles,
        DateTimeOffset startRentalAt,
        DateTimeOffset endRentalAt,
        int? durationDays,
        int? withDriverDurationHours,
        bool isOutOfTown,
        decimal dailyRate,
        decimal subtotalRental,
        decimal subtotalAmount,
        decimal taxAmount,
        decimal totalAmount,
        string idempotencyKey,
        string transactionId,
        DateTimeOffset paymentExpiresAt)
    {
        var order = new BookingOrder
        {
            BookingCode = bookingCode,
            CustomerId = customerId,
            CustomerName = customerName,
            CustomerPhone = customerPhone,
            CustomerEmail = customerEmail,
            ServiceType = serviceType,
            VehicleType = vehicleType,
            VehicleCategory = vehicleCategory,
            NumberOfVehicles = numberOfVehicles,
            StartRentalAt = startRentalAt,
            EndRentalAt = endRentalAt,
            DurationDays = durationDays,
            WithDriverDurationHours = withDriverDurationHours,
            IsOutOfTown = isOutOfTown,
            DailyRate = dailyRate,
            SubtotalRental = subtotalRental,
            SubtotalAmount = subtotalAmount,
            TaxAmount = taxAmount,
            TotalAmount = totalAmount,
            IdempotencyKey = idempotencyKey,
            TransactionId = transactionId,
            PaymentExpiresAt = paymentExpiresAt,
        };

        return order;
    }

    public void MarkPaid(DateTimeOffset paidAt)
    {
        Status = BookingStatus.Paid;
        PaidAt = paidAt;
        MarkUpdated();
    }

    public void Confirm(DateTimeOffset confirmedAt)
    {
        Status = BookingStatus.Confirmed;
        ConfirmedAt = confirmedAt;
        MarkUpdated();
    }

    public void SetActive()
    {
        Status = BookingStatus.Active;
        MarkUpdated();
    }

    public void Complete(DateTimeOffset completedAt)
    {
        Status = BookingStatus.Completed;
        CompletedAt = completedAt;
        MarkUpdated();
    }

    public void Expire(DateTimeOffset expiredAt)
    {
        Status = BookingStatus.Expired;
        ExpiredAt = expiredAt;
        MarkUpdated();
    }

    public void Cancel(string reason, DateTimeOffset cancelledAt)
    {
        Status = BookingStatus.Cancelled;
        CancellationReason = reason;
        CancelledAt = cancelledAt;
        MarkUpdated();
    }

    public void AssignVehicle(
        Guid vehicleId,
        string registrationNumber,
        string brand,
        string model,
        string? color)
    {
        AssignedVehicleId = vehicleId;
        VehicleRegistrationNumber = registrationNumber;
        VehicleBrand = brand;
        VehicleModel = model;
        VehicleColor = color;
        MarkUpdated();
    }

    public void AssignDriver(Guid driverId, string driverName, string driverPhone)
    {
        AssignedDriverId = driverId;
        DriverName = driverName;
        DriverPhone = driverPhone;
        MarkUpdated();
    }
}
