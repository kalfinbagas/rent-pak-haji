-- ═══════════════════════════════════════════════════════════════════════════
--  RENT PAK HAJI — rpk_bookingorder Schema
--  Owner   : BookingOrder Service (.NET)
--  Author  : Rizkalfin Bagas Aminullah
--  Version : 1.0.0  |  May 2026
--
--  Tabel dalam DB ini:
--    1. booking_order          → Header order (customer snapshot, status, total)
--    2. booking_order_detail   → Line item per kendaraan (waktu, lokasi, harga snapshot)
--    3. vehicle_soft_booking   → Soft hold stok selama payment window (15 menit)
--    4. vehicle_assignment     → Assignment kendaraan + driver + NFC saat dispatch
--    5. outbox_message         → Reliable event delivery (Outbox pattern)
--
--  Cross-service patterns (dari SERA):
--    ✓ transactionId           → Saga/event correlation ID (SERA: transactionId)
--    ✓ Sequence field          → Riwayat reassignment tetap terjaga (SERA pattern)
--    ✓ NumberOfVehicles        → Support multi-unit per line (SERA: jumlah unit)
--    ✓ Denormalized snapshots  → Tidak ada FK lintas DB (SERA denorm pattern)
--    ✓ IdempotencyKey          → Cegah double-submit (SERA: uniqueKey pattern)
--    ✓ AssignmentStatus        → Terpisah dari Status utama agar history terjaga
-- ═══════════════════════════════════════════════════════════════════════════

\c rpk_bookingorder;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────
-- ENUM TYPES
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE booking_status AS ENUM (
    'AWAITING_PAYMENT', 'PAID', 'CONFIRMED', 'ACTIVE',
    'COMPLETED', 'CANCELLED', 'EXPIRED', 'REFUNDED'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE assignment_status_main AS ENUM (
    'PENDING', 'DISPATCHED', 'ACTIVE', 'RETURNED', 'CANCELLED'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE soft_booking_status AS ENUM (
    'ACTIVE', 'EXPIRED', 'CONVERTED', 'RELEASED'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════════
-- TABEL 1: BOOKING_ORDER
-- Header order rental. Satu order bisa punya banyak detail line.
-- Semua data customer disimpan sebagai snapshot — tidak ada FK ke rpk_master.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS booking_order (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Kode booking yang tampil ke user
    booking_code        VARCHAR(20)     UNIQUE NOT NULL,
    -- Format: RPH-YYYYMMDD-XXXX  e.g. RPH-20260509-0001
    -- Generate di application layer sebelum INSERT

    -- Customer snapshot (dari Master Service via event — tidak ada FK ke rpk_master)
    customer_id         UUID            NOT NULL,
    customer_name       VARCHAR(150)    NOT NULL,    -- snapshot saat order dibuat
    customer_phone      VARCHAR(20)     NOT NULL,    -- snapshot
    customer_email      VARCHAR(150),                -- snapshot, nullable

    -- Status order
    status              booking_status  NOT NULL DEFAULT 'AWAITING_PAYMENT',

    -- Pembayaran
    total_amount        DECIMAL(18,2)   NOT NULL,    -- total setelah semua diskon
    subtotal_amount     DECIMAL(18,2)   NOT NULL,    -- sebelum diskon
    tax_amount          DECIMAL(18,2)   NOT NULL DEFAULT 0,

    -- Voucher (jika dipakai)
    voucher_code        VARCHAR(50),                 -- kode voucher yang dipakai
    voucher_discount    DECIMAL(18,2)   NOT NULL DEFAULT 0,

    -- Special price flag
    has_special_price   BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Idempotency — cegah double submit dari client
    -- [SERA: uniqueKey pattern]
    idempotency_key     VARCHAR(100)    UNIQUE NOT NULL,

    -- Saga correlation [SERA: transactionId]
    transaction_id      VARCHAR(100)    NOT NULL,

    -- Catatan operator
    operator_notes      TEXT,

    -- ─── PAYMENT EXPIRY ───────────────────────────────────────
    -- Deadline pembayaran. Diset saat order dibuat: NOW() + payment_window (default 15 menit).
    -- Selama payment_expires_at > NOW() dan status = AWAITING_PAYMENT:
    --   • Order masih bisa dibayar
    --   • vehicle_soft_booking status = ACTIVE → stok berkurang (soft hold)
    -- Jika payment_expires_at terlewat tanpa pembayaran:
    --   • Scheduler → UPDATE status = EXPIRED
    --   • Scheduler → UPDATE vehicle_soft_booking status = EXPIRED
    --   • Publish BookingExpired + SoftBookingReleased → Inventory kembalikan stok
    -- Jika dibayar sebelum expires_at:
    --   • UPDATE status = PAID, paid_at = NOW()
    --   • UPDATE vehicle_soft_booking status = CONVERTED → stok benar-benar terkurang
    --   • Publish PaymentSuccess + SoftBookingConverted → Inventory update replicated record
    payment_expires_at  TIMESTAMPTZ     NOT NULL,    -- deadline bayar, sama dengan soft_booking.expires_at

    -- Timestamps lifecycle
    paid_at             TIMESTAMPTZ,                 -- kapan pembayaran berhasil dikonfirmasi
    confirmed_at        TIMESTAMPTZ,                 -- kapan operator konfirmasi dispatch-ready
    completed_at        TIMESTAMPTZ,                 -- kapan rental selesai (journey COMPLETED)
    expired_at          TIMESTAMPTZ,                 -- kapan order di-expire oleh scheduler
    cancelled_at        TIMESTAMPTZ,                 -- kapan order dibatalkan (post-payment cancel)
    cancellation_reason TEXT,

    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bo_customer   ON booking_order(customer_id);
CREATE INDEX IF NOT EXISTS idx_bo_status     ON booking_order(status);
CREATE INDEX IF NOT EXISTS idx_bo_code       ON booking_order(booking_code);
CREATE INDEX IF NOT EXISTS idx_bo_created    ON booking_order(created_at DESC);
-- Partial index khusus scheduler expiry — hanya baris AWAITING_PAYMENT yang dipantau
CREATE INDEX IF NOT EXISTS idx_bo_expires    ON booking_order(payment_expires_at)
    WHERE status = 'AWAITING_PAYMENT';
COMMENT ON TABLE booking_order IS 'Header order rental — customer snapshot, status, total amount, voucher. Satu order → banyak booking_order_detail';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 2: BOOKING_ORDER_DETAIL
-- Line item per kendaraan dalam satu order.
-- Menyimpan: tipe kendaraan, window waktu rental (UTC), lokasi pickup/return,
-- dan harga snapshot saat booking dibuat.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS booking_order_detail (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_order_id    UUID            NOT NULL REFERENCES booking_order(id) ON DELETE CASCADE,
    line_number         INT             NOT NULL,    -- urutan line dalam order (1, 2, ...)

    -- Spesifikasi kendaraan yang diminta
    vehicle_type        VARCHAR(20)     NOT NULL CHECK (vehicle_type IN ('CAR','MOTORCYCLE')),
    vehicle_category    VARCHAR(30),                 -- SUV, MPV, Matic, Bebek — opsional filter

    -- Jumlah unit (support multi-unit per line — dari SERA NumberOfVehicles pattern)
    number_of_vehicles  INT             NOT NULL DEFAULT 1,

    -- Window rental — disimpan dalam UTC (SERA timezone pattern)
    start_rental_at     TIMESTAMPTZ     NOT NULL,    -- waktu mulai dalam UTC
    end_rental_at       TIMESTAMPTZ     NOT NULL,    -- waktu selesai dalam UTC
    start_timezone      VARCHAR(60)     NOT NULL DEFAULT 'Asia/Jakarta',
    -- e.g. Asia/Jakarta (WIB), Asia/Makassar (WITA), Asia/Jayapura (WIT)
    end_timezone        VARCHAR(60)     NOT NULL DEFAULT 'Asia/Jakarta',
    -- return timezone bisa berbeda dari pickup (one-way lintas zone)

    -- Lokasi pickup
    pickup_location_id      UUID,                   -- reference ke pool (no FK)
    pickup_location_name    VARCHAR(200)    NOT NULL,
    pickup_latitude         DECIMAL(11,8)   NOT NULL DEFAULT 0,
    pickup_longitude        DECIMAL(11,8)   NOT NULL DEFAULT 0,

    -- Lokasi return (bisa berbeda dari pickup — one-way rental)
    return_location_id      UUID,                   -- reference ke pool (no FK)
    return_location_name    VARCHAR(200)    NOT NULL,
    return_latitude         DECIMAL(11,8)   NOT NULL DEFAULT 0,
    return_longitude        DECIMAL(11,8)   NOT NULL DEFAULT 0,

    -- Pool utama untuk buku stok
    pool_location_id        UUID            NOT NULL,
    pool_location_name      VARCHAR(150)    NOT NULL,  -- snapshot dari Master event

    -- Durasi & harga
    duration_days       INT             NOT NULL,    -- dibulatkan ke atas (CEIL)
    daily_rate          DECIMAL(18,2)   NOT NULL,    -- harga snapshot saat booking — tidak berubah
    subtotal            DECIMAL(18,2)   NOT NULL,    -- duration_days × daily_rate × number_of_vehicles

    -- Opsi tambahan
    with_driver         BOOLEAN         NOT NULL DEFAULT FALSE,
    driver_daily_rate   DECIMAL(18,2),               -- harga driver per hari (jika with_driver)

    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    UNIQUE(booking_order_id, line_number)
);

CREATE INDEX IF NOT EXISTS idx_bod_order     ON booking_order_detail(booking_order_id);
CREATE INDEX IF NOT EXISTS idx_bod_pool      ON booking_order_detail(pool_location_id);
CREATE INDEX IF NOT EXISTS idx_bod_type      ON booking_order_detail(vehicle_type);
CREATE INDEX IF NOT EXISTS idx_bod_start     ON booking_order_detail(start_rental_at);
COMMENT ON TABLE booking_order_detail IS 'Line item per kendaraan dalam order — tipe, window waktu UTC, lokasi pickup/return, harga snapshot, jumlah unit';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 3: VEHICLE_SOFT_BOOKING (di rpk_bookingorder)
-- Dibuat saat customer create BookingOrder, sebelum payment.
-- Mengurangi effective stock selama payment window (default 15 menit).
-- Jika tidak dibayar sebelum ExpiresAt → status EXPIRED, stok kembali.
--
-- [SERA: VehicleSoftBooking pattern]
-- Direplikasi ke rpk_vehicle via event SoftBookingCreated/Released
-- untuk keperluan Inventory Service menghitung available stock.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_soft_booking (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    booking_order_id    UUID            NOT NULL REFERENCES booking_order(id) ON DELETE CASCADE,
    booking_code        VARCHAR(20)     NOT NULL,    -- denorm untuk tracing tanpa join
    booking_detail_id   UUID            NOT NULL REFERENCES booking_order_detail(id),

    -- Spesifikasi stok yang di-hold
    vehicle_type        VARCHAR(20)     NOT NULL,
    pool_location_id    UUID            NOT NULL,
    pool_location_name  VARCHAR(150)    NOT NULL,    -- snapshot

    -- Window soft booking (sama dengan detail window)
    start_rental_at     TIMESTAMPTZ     NOT NULL,
    end_rental_at       TIMESTAMPTZ     NOT NULL,

    -- Jumlah unit yang di-hold [SERA: NumberOfVehicles]
    number_of_vehicles  INT             NOT NULL DEFAULT 1,

    -- Expiry — auto release jika tidak dibayar
    expires_at          TIMESTAMPTZ     NOT NULL,    -- default: created_at + 15 menit

    status              soft_booking_status NOT NULL DEFAULT 'ACTIVE',

    -- [SERA: Sequence] — urutan soft booking dalam satu order (support multi-line)
    sequence            INT             NOT NULL DEFAULT 1,

    -- [SERA: transactionId] — saga correlation untuk Inventory Service
    transaction_id      VARCHAR(100)    NOT NULL,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vsb_order     ON vehicle_soft_booking(booking_order_id);
CREATE INDEX IF NOT EXISTS idx_vsb_pool      ON vehicle_soft_booking(pool_location_id);
CREATE INDEX IF NOT EXISTS idx_vsb_status    ON vehicle_soft_booking(status);
CREATE INDEX IF NOT EXISTS idx_vsb_expires   ON vehicle_soft_booking(expires_at)
    WHERE status = 'ACTIVE';   -- partial index — hanya ACTIVE yang perlu dipantau scheduler
CREATE INDEX IF NOT EXISTS idx_vsb_window    ON vehicle_soft_booking(start_rental_at, end_rental_at);
COMMENT ON TABLE vehicle_soft_booking IS 'Soft hold stok selama payment window (15 menit). Direplikasi ke rpk_vehicle via event. SERA: VehicleSoftBooking pattern';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 4: VEHICLE_ASSIGNMENT (di rpk_bookingorder)
-- Dibuat operator saat dispatch kendaraan ke order yang sudah PAID.
-- Berisi snapshot kendaraan, driver, NFC card.
-- BookingOrder Service butuh ini untuk tampilkan detail dispatch ke customer.
--
-- [SERA: VehicleAssignment pattern]
-- Direplikasi ke rpk_vehicle via event VehicleAssigned/AssignmentCancelled.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_assignment (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    booking_order_id    UUID            NOT NULL REFERENCES booking_order(id),
    booking_detail_id   UUID            NOT NULL REFERENCES booking_order_detail(id),
    booking_code        VARCHAR(20)     NOT NULL,    -- denorm untuk tracing tanpa join

    -- Kendaraan yang di-assign (snapshot dari Inventory Service via event)
    vehicle_id          UUID            NOT NULL,    -- reference ke rpk_vehicle — no FK
    license_plate       VARCHAR(15)     NOT NULL,    -- snapshot
    vehicle_type        VARCHAR(20)     NOT NULL,    -- snapshot: CAR, MOTORCYCLE
    vehicle_category    VARCHAR(30),                 -- snapshot
    brand               VARCHAR(50)     NOT NULL,    -- snapshot
    model               VARCHAR(50)     NOT NULL,    -- snapshot
    vehicle_year        INT,                         -- snapshot
    color               VARCHAR(30),                 -- snapshot

    -- Driver (opsional — jika with_driver = true)
    driver_id           UUID,                        -- reference ke rpk_driver — no FK
    driver_name         VARCHAR(150),                -- snapshot
    driver_phone        VARCHAR(20),                 -- snapshot

    -- NFC Card yang di-assign ke booking ini
    nfc_card_uid        VARCHAR(50),                 -- UID kartu NFC

    -- Pool dispatch
    dispatch_pool_id    UUID            NOT NULL,    -- pool asal dispatch
    dispatch_pool_name  VARCHAR(150)    NOT NULL,    -- snapshot

    -- Pool return (bisa berbeda untuk one-way)
    return_pool_id      UUID,
    return_pool_name    VARCHAR(150),

    -- Timing
    assigned_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    dispatched_at       TIMESTAMPTZ,                 -- kapan kendaraan benar-benar keluar pool
    returned_at         TIMESTAMPTZ,                 -- kapan kendaraan kembali ke pool

    -- Status utama assignment
    status              assignment_status_main NOT NULL DEFAULT 'PENDING',

    -- [SERA: AssignmentStatus] — terpisah dari status utama agar history reassignment terjaga
    -- 0=ASSIGNED, 1=RELEASED, 2=REJECTED
    assignment_status   SMALLINT        NOT NULL DEFAULT 0,

    -- [SERA: Sequence] — urutan assignment, menyimpan riwayat jika kendaraan diganti
    sequence            INT             NOT NULL DEFAULT 1,

    -- Alasan release/reject
    -- [SERA: ReasonType] — kategori alasan
    release_reason_type SMALLINT,
    -- 0=Vehicle Issue, 1=Driver Issue, 2=Customer Cancel, 3=Operator Override
    release_reason_note TEXT,
    released_at         TIMESTAMPTZ,
    released_by         VARCHAR(100),                -- username/ID operator

    -- [SERA: transactionId] — saga ID saat dispatch flow
    transaction_id      VARCHAR(100)    NOT NULL,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_va_order      ON vehicle_assignment(booking_order_id);
CREATE INDEX IF NOT EXISTS idx_va_vehicle    ON vehicle_assignment(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_va_status     ON vehicle_assignment(status);
CREATE INDEX IF NOT EXISTS idx_va_nfc        ON vehicle_assignment(nfc_card_uid) WHERE nfc_card_uid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_va_dispatch   ON vehicle_assignment(dispatch_pool_id);
COMMENT ON TABLE vehicle_assignment IS 'Assignment kendaraan + driver + NFC ke booking. Direplikasi ke rpk_vehicle via event. SERA: VehicleAssignment pattern dengan Sequence + AssignmentStatus terpisah';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 5: OUTBOX_MESSAGE
-- Reliable event delivery — ditulis dalam transaksi yang sama dengan
-- perubahan bisnis, kemudian di-publish ke RabbitMQ oleh Outbox Publisher.
-- Setiap service punya outbox sendiri (SERA & doc v9 pattern).
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS outbox_message (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    exchange        VARCHAR(100) NOT NULL,       -- RabbitMQ exchange target
    routing_key     VARCHAR(100) NOT NULL,       -- routing key untuk event
    event_type      VARCHAR(100) NOT NULL,       -- nama event class
    payload         JSONB       NOT NULL,        -- serialized event payload
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','PROCESSING','PUBLISHED','FAILED')),
    retry_count     INT         NOT NULL DEFAULT 0,
    max_retry       INT         NOT NULL DEFAULT 3,
    error_message   TEXT,
    -- Correlation untuk tracing [SERA: transactionId]
    correlation_id  VARCHAR(100),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ,
    next_retry_at   TIMESTAMPTZ                  -- untuk exponential backoff
);

CREATE INDEX IF NOT EXISTS idx_outbox_status  ON outbox_message(status, created_at)
    WHERE status IN ('PENDING','FAILED');        -- partial index — hanya yang perlu diproses
CREATE INDEX IF NOT EXISTS idx_outbox_retry   ON outbox_message(next_retry_at)
    WHERE status = 'FAILED' AND retry_count < max_retry;

COMMENT ON TABLE outbox_message IS 'Outbox pattern — event ditulis bersamaan dengan transaksi bisnis, di-publish ke RabbitMQ oleh Coravel scheduler';

-- ═══════════════════════════════════════════════════════════════
-- HELPER VIEWS (opsional, untuk debugging & monitoring)
-- ═══════════════════════════════════════════════════════════════

-- View: Order summary dengan status soft booking & assignment
CREATE OR REPLACE VIEW v_booking_summary AS
SELECT
    bo.id,
    bo.booking_code,
    bo.customer_name,
    bo.customer_phone,
    bo.status,
    bo.total_amount,
    bo.payment_expires_at,
    EXTRACT(EPOCH FROM (bo.payment_expires_at - NOW())) / 60 AS payment_minutes_remaining,
    bo.created_at,
    bo.paid_at,
    COUNT(DISTINCT bod.id)       AS total_lines,
    SUM(bod.number_of_vehicles)  AS total_vehicles,
    COUNT(DISTINCT vsb.id) FILTER (WHERE vsb.status = 'ACTIVE')      AS active_soft_bookings,
    COUNT(DISTINCT vsb.id) FILTER (WHERE vsb.status = 'CONVERTED')   AS converted_soft_bookings,
    COUNT(DISTINCT va.id)  FILTER (WHERE va.assignment_status = 0)   AS active_assignments,
    MIN(bod.start_rental_at) AS earliest_start,
    MAX(bod.end_rental_at)   AS latest_end
FROM booking_order bo
LEFT JOIN booking_order_detail bod ON bod.booking_order_id = bo.id
LEFT JOIN vehicle_soft_booking vsb  ON vsb.booking_order_id = bo.id
LEFT JOIN vehicle_assignment va     ON va.booking_order_id = bo.id
GROUP BY bo.id;

-- View: Active soft bookings yang akan expired (untuk monitoring scheduler)
CREATE OR REPLACE VIEW v_expiring_soft_bookings AS
SELECT
    vsb.id,
    vsb.booking_code,
    vsb.vehicle_type,
    vsb.pool_location_name,
    vsb.number_of_vehicles,
    vsb.expires_at,
    EXTRACT(EPOCH FROM (vsb.expires_at - NOW())) / 60 AS minutes_until_expiry,
    bo.status AS order_status
FROM vehicle_soft_booking vsb
JOIN booking_order bo ON bo.id = vsb.booking_order_id
WHERE vsb.status = 'ACTIVE'
ORDER BY vsb.expires_at ASC;

-- ─────────────────────────────────────────────────────────────
-- View: Orders yang sudah expired dan perlu di-cancel oleh scheduler
-- Coravel job query: SELECT * FROM v_expiring_orders LIMIT 100
-- Lalu untuk setiap row: UPDATE booking_order + vehicle_soft_booking + publish events
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_expiring_orders AS
SELECT
    bo.id                   AS booking_order_id,
    bo.booking_code,
    bo.customer_id,
    bo.customer_name,
    bo.customer_phone,
    bo.total_amount,
    bo.payment_expires_at,
    bo.transaction_id,
    -- Hitung berapa soft booking ACTIVE yang perlu di-expire
    COUNT(vsb.id)           AS active_soft_booking_count,
    SUM(vsb.number_of_vehicles) AS total_held_vehicles
FROM booking_order bo
LEFT JOIN vehicle_soft_booking vsb
    ON vsb.booking_order_id = bo.id AND vsb.status = 'ACTIVE'
WHERE bo.status = 'AWAITING_PAYMENT'
  AND bo.payment_expires_at < NOW()   -- deadline sudah lewat
GROUP BY bo.id;

-- ─────────────────────────────────────────────────────────────
-- View: Dispatch queue (order PAID yang belum di-assign)
CREATE OR REPLACE VIEW v_pending_dispatch AS
SELECT
    bo.booking_code,
    bo.customer_name,
    bo.customer_phone,
    bod.vehicle_type,
    bod.vehicle_category,
    bod.number_of_vehicles,
    bod.pool_location_name,
    bod.start_rental_at AT TIME ZONE 'Asia/Jakarta' AS start_local,
    bod.end_rental_at   AT TIME ZONE 'Asia/Jakarta' AS end_local,
    bod.with_driver,
    bo.paid_at,
    -- Hitung berapa unit yang sudah di-assign
    COALESCE(
      (SELECT COUNT(*) FROM vehicle_assignment va
       WHERE va.booking_detail_id = bod.id AND va.assignment_status = 0),
      0
    ) AS assigned_units,
    bod.number_of_vehicles - COALESCE(
      (SELECT COUNT(*) FROM vehicle_assignment va
       WHERE va.booking_detail_id = bod.id AND va.assignment_status = 0),
      0
    ) AS remaining_units
FROM booking_order bo
JOIN booking_order_detail bod ON bod.booking_order_id = bo.id
WHERE bo.status = 'PAID'
ORDER BY bod.start_rental_at ASC;
