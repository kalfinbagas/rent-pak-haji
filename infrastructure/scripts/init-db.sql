-- ═══════════════════════════════════════════════════════════════════════════
--  RENT PAK HAJI — Database Initialization
--  Arsitektur: 1 Service = 1 Database (SERA pattern)
--  Author  : Rizkalfin Bagas Aminullah
--  Version : 2.0.0  |  May 2026
--
--  SERA Adaptations (v2.0):
--    * rpk_master    → Enhanced dengan PoolLocationHierarchy, ApprovalMatrix
--    * rpk_vehicle   → Enhanced dengan VehicleCategory, Preparation, Transfer, Allocation
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- NOTE: rpk_master sudah dibuat otomatis oleh POSTGRES_DB env var
--       di docker-compose.yml, jadi tidak perlu CREATE di sini.
--       Script ini hanya membuat database-database tambahan.
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- 1. rpk_vehicle → Inventory Service (.NET)
--    v2.0 Tables: MasterVehicle (+ FK lookups, preparation, condition flags),
--                 VehicleCategory, VehicleTransmissionType,
--                 VehicleMovement (+ movementType, movementSource),
--                 VehiclePreparation, VehicleTransfer, VehicleTransferDetail,
--                 VehicleTransferApproval, VehiclePoolAllocation,
--                 PoolInOutDashboard, VehicleStandby, VehicleStandbyMapping,
--                 VehicleSoftBooking (replicated dari rpk_bookingorder via event),
--                 VehicleAssignment  (replicated dari rpk_bookingorder via event),
--                 OutboxMessage
-- ─────────────────────────────────────────────────────────────
CREATE DATABASE rpk_vehicle;
GRANT ALL PRIVILEGES ON DATABASE rpk_vehicle TO rpk_admin;

-- ─────────────────────────────────────────────────────────────
-- 3. rpk_driver → Driver Service (.NET)
--    Tables: Driver, DriverAssignment, OutboxMessage
-- ─────────────────────────────────────────────────────────────
CREATE DATABASE rpk_driver;
GRANT ALL PRIVILEGES ON DATABASE rpk_driver TO rpk_admin;

-- ─────────────────────────────────────────────────────────────
-- 4. rpk_bookingorder → BookingOrder Service (.NET)
--    Tables: BookingOrder, BookingOrderDetail,
--            VehicleSoftBooking (+ SERA: Sequence, NumberOfVehicles, TransactionId),
--            VehicleAssignment  (+ SERA: Sequence, AssignmentStatus, ReasonType),
--            Views: v_booking_summary, v_expiring_soft_bookings, v_pending_dispatch,
--            OutboxMessage
-- ─────────────────────────────────────────────────────────────
CREATE DATABASE rpk_bookingorder;
GRANT ALL PRIVILEGES ON DATABASE rpk_bookingorder TO rpk_admin;

-- ─────────────────────────────────────────────────────────────
-- 5. rpk_journey → Journey Service (.NET)
--    Tables: Journey, Dispatch (+ preparationStatus), Return, OutboxMessage
-- ─────────────────────────────────────────────────────────────
CREATE DATABASE rpk_journey;
GRANT ALL PRIVILEGES ON DATABASE rpk_journey TO rpk_admin;

-- ─────────────────────────────────────────────────────────────
-- 6. rpk_payment → Payment Service (.NET)
--    Tables: Payment, Invoice, OutboxMessage
-- ─────────────────────────────────────────────────────────────
CREATE DATABASE rpk_payment;
GRANT ALL PRIVILEGES ON DATABASE rpk_payment TO rpk_admin;

-- ─────────────────────────────────────────────────────────────
-- 7. rpk_saga → Saga Orchestrator (.NET)
--    Tables: SagaState, SagaStep
-- ─────────────────────────────────────────────────────────────
CREATE DATABASE rpk_saga;
GRANT ALL PRIVILEGES ON DATABASE rpk_saga TO rpk_admin;

-- ─────────────────────────────────────────────────────────────
-- 8. rpk_notification → Notification Service (NestJS)
--    Tables: NotificationLog, NotificationTemplate
-- ─────────────────────────────────────────────────────────────
CREATE DATABASE rpk_notification;
GRANT ALL PRIVILEGES ON DATABASE rpk_notification TO rpk_admin;

-- ─────────────────────────────────────────────────────────────
-- 9. rpk_voucher → Voucher Service (NestJS)
--    Tables: Voucher, SpecialPrice, OutboxMessage
-- ─────────────────────────────────────────────────────────────
CREATE DATABASE rpk_voucher;
GRANT ALL PRIVILEGES ON DATABASE rpk_voucher TO rpk_admin;
