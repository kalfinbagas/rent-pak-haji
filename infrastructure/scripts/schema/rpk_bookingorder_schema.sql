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
--  Cross-service patterns:
--    ✓ transaction_id          → Saga/event correlation ID
--    ✓ Sequence field          → Riwayat reassignment tetap terjaga
--    ✓ NumberOfVehicles        → Support multi-unit per order
--    ✓ Denormalized snapshots  → Tidak ada FK lintas DB
--    ✓ IdempotencyKey          → Cegah double-submit
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
  CREATE TYPE service_type_enum AS ENUM (
    'SELF_DRIVE',   -- customer mengemudi sendiri, durasi kelipatan 24 jam min 1 hari
    'WITH_DRIVER'   -- disertai driver, durasi pilihan: 4/6/8/12/16 jam atau multi-day stay
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE expedition_type_enum AS ENUM (
    'SELF_SERVICE',  -- customer handle sendiri (ambil/kembalikan ke pool)
    'EXPEDITION'     -- operator antar/jemput ke alamat customer (biaya ekspedisi berlaku)
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
-- Header order rental.
-- Menyimpan: info customer (snapshot), spesifikasi kendaraan, pricing,
-- window rental, dan semua field yang dibutuhkan untuk stok & pembayaran.
-- Satu order selalu punya tepat 2 booking_order_detail: START dan END.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS booking_order (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Kode booking yang tampil ke user
    -- Format: RPH-YYYYMMDD-XXXX  e.g. RPH-20260509-0001
    booking_code        VARCHAR(20)     UNIQUE NOT NULL,

    -- Tipe service [BUSINESS RULE]
    -- SELF_DRIVE : durasi kelipatan 24 jam, min 1 hari, akun terverifikasi
    -- WITH_DRIVER: pilihan durasi 4/6/8/12/16 jam atau stay multi-day
    service_type        service_type_enum NOT NULL,

    -- Customer snapshot — tidak ada FK ke rpk_master
    customer_id         UUID            NOT NULL,
    customer_name       VARCHAR(150)    NOT NULL,
    customer_phone      VARCHAR(20)     NOT NULL,
    customer_email      VARCHAR(150),

    -- ─── SPESIFIKASI KENDARAAN (permintaan customer) ───────────
    vehicle_type        VARCHAR(20)     NOT NULL CHECK (vehicle_type IN ('CAR','MOTORCYCLE')),
    vehicle_category    VARCHAR(30),                 -- SUV, MPV, Matic, Bebek — opsional filter
    number_of_vehicles  INT             NOT NULL DEFAULT 1,

    -- ─── KENDARAAN YANG DI-ASSIGN (diisi operator saat dispatch) ─
    -- NULL saat order dibuat, diupdate setelah operator assign unit
    assigned_vehicle_id             UUID,
    vehicle_registration_number     VARCHAR(20),     -- plat nomor, e.g. B 1234 ABC
    vehicle_brand                   VARCHAR(50),     -- snapshot: Toyota, Honda, dll
    vehicle_model                   VARCHAR(50),     -- snapshot: Avanza, Brio, dll
    vehicle_color                   VARCHAR(30),     -- snapshot: Putih, Hitam, dll

    -- ─── DRIVER YANG DI-ASSIGN (diisi operator saat dispatch) ───
    -- NULL untuk Self Drive atau sebelum dispatch
    assigned_driver_id              UUID,
    driver_name                     VARCHAR(150),    -- snapshot nama driver
    driver_phone                    VARCHAR(20),     -- snapshot nomor HP driver

    -- ─── WINDOW RENTAL (UTC) ───────────────────────────────────
    -- SELF_DRIVE : end = start + (duration_days × 24 jam), end time = start time
    --              Contoh: 1 Jan 10:00 + 1 hari = 2 Jan 10:00
    -- WITH_DRIVER: end = start + with_driver_duration_hours
    start_rental_at     TIMESTAMPTZ     NOT NULL,
    end_rental_at       TIMESTAMPTZ     NOT NULL,
    start_timezone      VARCHAR(60)     NOT NULL DEFAULT 'Asia/Jakarta',
    end_timezone        VARCHAR(60)     NOT NULL DEFAULT 'Asia/Jakarta',

    -- ─── DURASI & HARGA ────────────────────────────────────────
    duration_days       INT             NOT NULL,    -- hari (Self Drive) atau 1 (With Driver)
    daily_rate          DECIMAL(18,2)   NOT NULL,    -- harga snapshot — tidak berubah setelah order
    subtotal_rental     DECIMAL(18,2)   NOT NULL,    -- duration_days × daily_rate × number_of_vehicles

    -- ─── WITH DRIVER OPTIONS ───────────────────────────────────
    with_driver                 BOOLEAN         NOT NULL DEFAULT FALSE,
    driver_daily_rate           DECIMAL(18,2),
    with_driver_duration_hours  INT             CHECK (with_driver_duration_hours IN (4,6,8,12,16)),
    is_out_of_town              BOOLEAN         NOT NULL DEFAULT FALSE,
    out_of_town_surcharge       DECIMAL(18,2)   NOT NULL DEFAULT 0,

    -- Status order
    status              booking_status  NOT NULL DEFAULT 'AWAITING_PAYMENT',

    -- ─── PEMBAYARAN ────────────────────────────────────────────
    -- total = subtotal_rental + out_of_town_surcharge
    --       + start_expedition_fee + end_expedition_fee
    --       + tax - voucher_discount
    subtotal_amount     DECIMAL(18,2)   NOT NULL,    -- sebelum tax & diskon
    tax_amount          DECIMAL(18,2)   NOT NULL DEFAULT 0,
    total_amount        DECIMAL(18,2)   NOT NULL,    -- total akhir yang dibayar

    -- Voucher
    voucher_code        VARCHAR(50),
    voucher_discount    DECIMAL(18,2)   NOT NULL DEFAULT 0,
    has_special_price   BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Idempotency key — cegah double-submit
    idempotency_key     VARCHAR(100)    UNIQUE NOT NULL,

    -- Saga/event correlation ID
    transaction_id      VARCHAR(100)    NOT NULL,

    operator_notes      TEXT,

    -- ─── PAYMENT EXPIRY ───────────────────────────────────────
    -- Diset saat order dibuat: NOW() + 15 menit
    -- Scheduler cek setiap menit via v_expiring_orders
    payment_expires_at  TIMESTAMPTZ     NOT NULL,

    -- Lifecycle timestamps
    paid_at             TIMESTAMPTZ,
    confirmed_at        TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    expired_at          TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,
    cancellation_reason TEXT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bo_customer   ON booking_order(customer_id);
CREATE INDEX IF NOT EXISTS idx_bo_status     ON booking_order(status);
CREATE INDEX IF NOT EXISTS idx_bo_code       ON booking_order(booking_code);
CREATE INDEX IF NOT EXISTS idx_bo_vehicle    ON booking_order(assigned_vehicle_id);
CREATE INDEX IF NOT EXISTS idx_bo_driver     ON booking_order(assigned_driver_id);
CREATE INDEX IF NOT EXISTS idx_bo_start      ON booking_order(start_rental_at);
CREATE INDEX IF NOT EXISTS idx_bo_created    ON booking_order(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bo_expires    ON booking_order(payment_expires_at)
    WHERE status = 'AWAITING_PAYMENT';
COMMENT ON TABLE booking_order IS 'Header order rental — customer, kendaraan, pricing, window waktu. Selalu punya 2 booking_order_detail (START + END).';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 2: BOOKING_ORDER_DETAIL
-- Location record per titik serah-terima kendaraan.
-- 1 booking_order selalu punya tepat 2 record:
--   detail_type = 'START' → kapan & dimana unit diserahkan ke customer
--   detail_type = 'END'   → kapan & dimana unit dikembalikan dari customer
--
-- Expedition type per titik (independen):
--   SELF_SERVICE → customer ambil/kembalikan sendiri di pool
--   EXPEDITION   → operator antar/jemput ke/dari alamat customer
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS booking_order_detail (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_order_id    UUID            NOT NULL REFERENCES booking_order(id) ON DELETE CASCADE,

    -- START = awal rental, END = akhir rental
    detail_type         VARCHAR(5)      NOT NULL CHECK (detail_type IN ('START', 'END')),

    -- Waktu serah-terima untuk titik ini
    -- START → = booking_order.start_rental_at
    -- END   → = booking_order.end_rental_at
    scheduled_at        TIMESTAMPTZ     NOT NULL,
    timezone            VARCHAR(60)     NOT NULL DEFAULT 'Asia/Jakarta',

    -- ─── TIPE EKSPEDISI ────────────────────────────────────────
    expedition_type     expedition_type_enum NOT NULL DEFAULT 'SELF_SERVICE',

    -- Pool referensi (selalu diisi — pool asal/tujuan unit)
    pool_location_id    UUID            NOT NULL,
    pool_location_name  VARCHAR(150)    NOT NULL,   -- snapshot

    -- Alamat customer (diisi hanya jika expedition_type = EXPEDITION)
    address             TEXT,
    city                VARCHAR(100),
    district            VARCHAR(100),               -- kecamatan (untuk tarif ekspedisi)
    latitude            DECIMAL(11,8),
    longitude           DECIMAL(11,8),

    -- Biaya ekspedisi titik ini (0 jika SELF_SERVICE)
    expedition_fee      DECIMAL(18,2)   NOT NULL DEFAULT 0,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Setiap order hanya punya 1 START dan 1 END
    UNIQUE(booking_order_id, detail_type)
);

CREATE INDEX IF NOT EXISTS idx_bod_order     ON booking_order_detail(booking_order_id);
CREATE INDEX IF NOT EXISTS idx_bod_type      ON booking_order_detail(detail_type);
CREATE INDEX IF NOT EXISTS idx_bod_pool      ON booking_order_detail(pool_location_id);
CREATE INDEX IF NOT EXISTS idx_bod_sched     ON booking_order_detail(scheduled_at);
COMMENT ON TABLE booking_order_detail IS '2 record per order: START (antar/ambil) dan END (jemput/kembalikan). Menyimpan waktu & lokasi serah-terima + tipe ekspedisi per titik.';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 3: VEHICLE_SOFT_BOOKING (di rpk_bookingorder)
-- Dibuat saat customer create BookingOrder, sebelum payment.
-- Mengurangi effective stock selama payment window (default 15 menit).
-- Jika tidak dibayar sebelum ExpiresAt → status EXPIRED, stok kembali.
--
-- Direplikasi ke rpk_vehicle via event SoftBookingCreated/Released
-- untuk keperluan Inventory Service menghitung available stock.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_soft_booking (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    booking_order_id    UUID            NOT NULL REFERENCES booking_order(id) ON DELETE CASCADE,
    booking_code        VARCHAR(20)     NOT NULL,    -- denorm untuk tracing tanpa join

    -- Spesifikasi stok yang di-hold
    -- vehicle_type dari booking_order header
    -- pool_location_id dari booking_order_detail WHERE detail_type = 'START'
    vehicle_type        VARCHAR(20)     NOT NULL,
    pool_location_id    UUID            NOT NULL,
    pool_location_name  VARCHAR(150)    NOT NULL,    -- snapshot

    -- Window soft booking (sama dengan detail window)
    start_rental_at     TIMESTAMPTZ     NOT NULL,
    end_rental_at       TIMESTAMPTZ     NOT NULL,

    -- Jumlah unit yang di-hold
    number_of_vehicles  INT             NOT NULL DEFAULT 1,

    -- Expiry — auto release jika tidak dibayar
    expires_at          TIMESTAMPTZ     NOT NULL,    -- default: created_at + 15 menit

    status              soft_booking_status NOT NULL DEFAULT 'ACTIVE',

    -- urutan soft booking dalam satu order (support multi-line)
    sequence            INT             NOT NULL DEFAULT 1,

    -- saga/event correlation ID — digunakan Inventory Service
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
COMMENT ON TABLE vehicle_soft_booking IS 'Soft hold stok selama payment window (15 menit). Direplikasi ke rpk_vehicle via event SoftBookingCreated/Released. INSERT idempotent.';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 4: VEHICLE_ASSIGNMENT (di rpk_bookingorder)
-- Dibuat operator saat dispatch kendaraan ke order yang sudah PAID.
-- Berisi snapshot kendaraan, driver, NFC card.
-- BookingOrder Service butuh ini untuk tampilkan detail dispatch ke customer.
--
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

    -- status assignment numerik, terpisah dari status utama agar history reassignment terjaga
    -- 0=ASSIGNED, 1=RELEASED, 2=REJECTED
    assignment_status   SMALLINT        NOT NULL DEFAULT 0,

    -- urutan assignment — bertambah setiap kali kendaraan diganti (history terjaga)
    sequence            INT             NOT NULL DEFAULT 1,

    -- Alasan release/reject
    release_reason_type SMALLINT,   -- 0=Vehicle Issue, 1=Driver Issue, 2=Customer Cancel, 3=Operator Override
    -- 0=Vehicle Issue, 1=Driver Issue, 2=Customer Cancel, 3=Operator Override
    release_reason_note TEXT,
    released_at         TIMESTAMPTZ,
    released_by         VARCHAR(100),                -- username/ID operator

    -- saga/event correlation ID — digunakan saat dispatch flow
    transaction_id      VARCHAR(100)    NOT NULL,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_va_order      ON vehicle_assignment(booking_order_id);
CREATE INDEX IF NOT EXISTS idx_va_vehicle    ON vehicle_assignment(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_va_status     ON vehicle_assignment(status);
CREATE INDEX IF NOT EXISTS idx_va_nfc        ON vehicle_assignment(nfc_card_uid) WHERE nfc_card_uid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_va_dispatch   ON vehicle_assignment(dispatch_pool_id);
COMMENT ON TABLE vehicle_assignment IS 'Assignment kendaraan + driver + NFC ke booking. Direplikasi ke rpk_vehicle via VehicleAssigned event. Sequence bertambah setiap kendaraan diganti.';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 5: OUTBOX_MESSAGE
-- Reliable event delivery — ditulis dalam transaksi yang sama dengan
-- perubahan bisnis, kemudian di-publish ke RabbitMQ oleh Outbox Publisher.
-- Setiap service punya outbox sendiri (per-service isolation).
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
    -- saga/event correlation ID untuk tracing
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
