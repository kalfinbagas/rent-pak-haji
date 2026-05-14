namespace Vehicle.Domain.Enums;

public enum VehicleStatus
{
    Available,      // siap disewa
    Reserved,       // soft-booked (menunggu pembayaran)
    Ready,          // sudah diassign, menunggu dispatch
    InUse,          // sedang dalam order aktif
    ReturningSoon,  // mendekati waktu kembali
    LateReturn,     // melewati jadwal kembali
    Maintenance,    // servis / perawatan rutin
    Breakdown,      // mogok / kerusakan mendadak di lapangan
    Theft,          // dilaporkan hilang / dicuri
    Borrow,         // dipinjam internal (bukan order customer)
    Inactive        // non-aktif / disposal
}

public enum TransferStatus
{
    Draft,
    PendingApproval,
    Approved,
    Rejected,
    InTransit,
    Completed,
    Cancelled
}

public enum PreparationStatus
{
    Pending,
    InProgress,
    Completed,
    Skipped
}

public enum MovementType
{
    StatusChange,
    Dispatch,
    Return,
    Transfer,
    MaintenanceIn,
    MaintenanceOut,
    Allocation
}

public enum MovementSource
{
    Manual,
    BookingOrder,
    NfcGate,
    Scheduler,
    TransferRequest,
    Api
}

public enum AllocationStatus
{
    Draft,
    Pending,
    Approved,
    Active,
    Expired,
    Cancelled
}

public enum OwnershipType
{
    Own,
    Lease,
    Partner
}

public enum SoftBookingReplicaStatus
{
    Active,
    Expired,
    Converted,
    Released
}

public enum AssignmentReplicaStatus
{
    Pending,
    Dispatched,
    Active,
    Returned,
    Cancelled
}
