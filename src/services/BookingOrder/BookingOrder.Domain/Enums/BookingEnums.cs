namespace BookingOrder.Domain.Enums;

public enum BookingStatus
{
    AwaitingPayment,
    Paid,
    Confirmed,
    Active,
    Completed,
    Cancelled,
    Expired,
    Refunded
}

public enum ServiceType
{
    SelfDrive,      // kelipatan 24 jam, min 1 hari
    WithDriver      // 4/6/8/12/16 jam, atau multi-day stay
}

public enum ExpeditionType
{
    SelfService,    // customer ambil/kembalikan sendiri di pool
    Expedition      // operator antar/jemput ke/dari alamat customer
}

public enum SoftBookingStatus
{
    Active,
    Expired,
    Converted,
    Released
}

public enum AssignmentStatusMain
{
    Pending,
    Dispatched,
    Active,
    Returned,
    Cancelled
}
