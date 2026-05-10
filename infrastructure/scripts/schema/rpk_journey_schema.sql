-- ═══════════════════════════════════════════════════════════════════════════
--  RENT PAK HAJI — rpk_journey Schema
--  Owner   : Journey Service (.NET)
--  Author  : Rizkalfin Bagas Aminullah
--  Version : 1.0.0  |  May 2026
--
--  Tabel dalam DB ini:
--    1. journey           → Record perjalanan: dispatch + return dalam satu entitas
--    2. journey_pool_event→ Setiap event masuk/keluar pool (NFC gate / manual)
--    3. outbox_message    → Reliable event delivery (Outbox pattern)
--
--  Cross-service patterns:
--    ✓ Denormalized snapshots → Tidak ada FK lintas DB
--    ✓ transactionId          → Saga/event correlation
--    ✓ NFC gate integration   → journey_pool_event dari MQTT/NFC gateway
-- ═══════════════════════════════════════════════════════════════════════════

\c rpk_journey;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────
-- ENUM TYPES
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE journey_status AS ENUM (
    'SCHEDULED',    -- belum dispatch, sudah assigned
    'DISPATCHING',  -- sedang proses dispatch (preparation done, menunggu keluar gate)
    'IN_PROGRESS',  -- kendaraan sudah keluar, sedang digunakan customer
    'RETURNING',    -- customer sudah konfirmasi return, menuju pool
    'COMPLETED',    -- kendaraan sudah masuk pool, journey selesai
    'CANCELLED'     -- dibatalkan sebelum dispatch
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE pool_event_type AS ENUM (
    'POOL_OUT',     -- kendaraan keluar pool (dispatch)
    'POOL_IN'       -- kendaraan masuk pool (return)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE pool_event_source AS ENUM (
    'NFC_GATE',     -- triggered oleh scan NFC di gate
    'MANUAL',       -- diinput manual oleh operator
    'SYSTEM'        -- triggered oleh sistem (scheduler/API)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════════
-- TABEL 1: JOURNEY
-- Satu journey = satu perjalanan dari dispatch sampai return.
-- Linked ke booking_order + vehicle_assignment (cross-service, snapshot).
-- Journey Service bertanggung jawab atas lifecycle kendaraan saat
-- di tangan customer: keluar pool → sedang dipakai → kembali.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS journey (
    id                      UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Referensi ke BookingOrder Service (cross-service, no FK)
    booking_order_id        UUID            NOT NULL,
    booking_code            VARCHAR(20)     NOT NULL,   -- [denorm] untuk tracing tanpa join
    booking_detail_id       UUID            NOT NULL,   -- line item yang di-dispatch
    vehicle_assignment_id   UUID            NOT NULL,   -- ref ke rpk_bookingorder.vehicle_assignment

    -- Snapshot kendaraan (dari event VehicleAssigned)
    vehicle_id              UUID            NOT NULL,   -- ref ke rpk_vehicle.master_vehicle (no FK)
    license_plate           VARCHAR(15)     NOT NULL,   -- snapshot
    vehicle_type            VARCHAR(20)     NOT NULL,   -- snapshot: CAR / MOTORCYCLE
    vehicle_category        VARCHAR(30),                -- snapshot
    brand                   VARCHAR(50)     NOT NULL,   -- snapshot
    model                   VARCHAR(50)     NOT NULL,   -- snapshot

    -- Snapshot driver (opsional — jika with_driver)
    driver_id               UUID,
    driver_name             VARCHAR(150),               -- snapshot
    driver_phone            VARCHAR(20),                -- snapshot

    -- Snapshot NFC card
    nfc_card_uid            VARCHAR(50),                -- UID kartu NFC yang dipakai

    -- Snapshot customer
    customer_id             UUID            NOT NULL,
    customer_name           VARCHAR(150)    NOT NULL,   -- snapshot
    customer_phone          VARCHAR(20)     NOT NULL,   -- snapshot

    -- Pool dispatch & return
    dispatch_pool_id        UUID            NOT NULL,
    dispatch_pool_name      VARCHAR(150)    NOT NULL,   -- [denorm]
    return_pool_id          UUID,
    return_pool_name        VARCHAR(150),               -- [denorm] null = sama dengan dispatch pool

    -- Window rental (UTC — snapshot dari booking_order_detail)
    start_rental_at         TIMESTAMPTZ     NOT NULL,
    end_rental_at           TIMESTAMPTZ     NOT NULL,

    -- Status lifecycle journey
    status                  journey_status  NOT NULL DEFAULT 'SCHEDULED',

    -- Timestamps aktual
    dispatched_at           TIMESTAMPTZ,    -- kapan kendaraan benar-benar keluar pool (POOL_OUT event)
    returned_at             TIMESTAMPTZ,    -- kapan kendaraan benar-benar masuk pool (POOL_IN event)

    -- Catatan
    dispatch_notes          TEXT,           -- catatan operator saat dispatch
    return_notes            TEXT,           -- catatan operator saat return
    return_odometer         INT,            -- odometer saat kendaraan dikembalikan

    -- Saga correlation
    transaction_id          VARCHAR(100)    NOT NULL,   -- [SERA: transactionId]

    -- Audit
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_jrn_booking   ON journey(booking_order_id);
CREATE INDEX IF NOT EXISTS idx_jrn_vehicle   ON journey(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_jrn_status    ON journey(status);
CREATE INDEX IF NOT EXISTS idx_jrn_dispatch  ON journey(dispatch_pool_id);
CREATE INDEX IF NOT EXISTS idx_jrn_window    ON journey(start_rental_at, end_rental_at);

COMMENT ON TABLE journey IS
  'Satu journey = satu perjalanan dispatch-to-return. '
  'Snapshot kendaraan + driver + pool dari event VehicleAssigned. '
  'Status lifecycle: SCHEDULED → DISPATCHING → IN_PROGRESS → RETURNING → COMPLETED';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 2: JOURNEY_POOL_EVENT
-- Log setiap kejadian masuk/keluar pool — dapat berasal dari:
--   • NFC gate (via MQTT → NFC Gateway Service → Journey Service)
--   • Input manual operator (via API)
--   • Trigger sistem (scheduler timeout)
--
-- Digunakan untuk:
--   1. UPDATE journey.status (DISPATCHING → IN_PROGRESS saat POOL_OUT)
--   2. UPDATE journey.status (RETURNING → COMPLETED saat POOL_IN)
--   3. Publish event ke Inventory Service → UPDATE master_vehicle.status
--   4. Agregasi pool_in_out_dashboard di rpk_vehicle
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS journey_pool_event (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Referensi journey
    journey_id          UUID            NOT NULL,       -- ref ke journey (same DB, tapi no FK untuk immutability)
    booking_code        VARCHAR(20)     NOT NULL,       -- [denorm]

    -- Kendaraan snapshot
    vehicle_id          UUID            NOT NULL,
    license_plate       VARCHAR(15)     NOT NULL,       -- [denorm]

    -- Pool yang di-event
    pool_location_id    UUID            NOT NULL,
    pool_location_name  VARCHAR(150)    NOT NULL,       -- [denorm]

    -- Tipe event: masuk atau keluar pool
    event_type          pool_event_type NOT NULL,

    -- Sumber event
    event_source        pool_event_source NOT NULL DEFAULT 'MANUAL',

    -- Data NFC (jika event_source = NFC_GATE)
    nfc_card_uid        VARCHAR(50),    -- kartu yang discan
    gate_id             VARCHAR(50),    -- gate yang mendeteksi

    -- Operator yang input (jika MANUAL atau SYSTEM)
    operator_id         UUID,
    operator_name       VARCHAR(150),   -- [denorm]

    -- Metadata tambahan
    odometer_at         INT,            -- odometer saat event (untuk POOL_IN)
    notes               TEXT,

    -- Saga correlation
    transaction_id      VARCHAR(100),

    event_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW()   -- kapan event terjadi
);

CREATE INDEX IF NOT EXISTS idx_jpe_journey  ON journey_pool_event(journey_id);
CREATE INDEX IF NOT EXISTS idx_jpe_vehicle  ON journey_pool_event(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_jpe_pool     ON journey_pool_event(pool_location_id);
CREATE INDEX IF NOT EXISTS idx_jpe_type     ON journey_pool_event(event_type);
CREATE INDEX IF NOT EXISTS idx_jpe_at       ON journey_pool_event(event_at DESC);

COMMENT ON TABLE journey_pool_event IS
  'Log setiap event masuk/keluar pool — dari NFC gate (MQTT), manual operator, atau sistem. '
  'Trigger update status journey dan publish event ke Inventory Service.';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 3: OUTBOX_MESSAGE
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS outbox_message (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    exchange        VARCHAR(100) NOT NULL,
    routing_key     VARCHAR(100) NOT NULL,
    event_type      VARCHAR(100) NOT NULL,
    payload         JSONB       NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','PROCESSING','PUBLISHED','FAILED')),
    retry_count     INT         NOT NULL DEFAULT 0,
    max_retry       INT         NOT NULL DEFAULT 3,
    error_message   TEXT,
    correlation_id  VARCHAR(100),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ,
    next_retry_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_outbox_status  ON outbox_message(status, created_at)
    WHERE status IN ('PENDING','FAILED');
CREATE INDEX IF NOT EXISTS idx_outbox_retry   ON outbox_message(next_retry_at)
    WHERE status = 'FAILED' AND retry_count < max_retry;

COMMENT ON TABLE outbox_message IS 'Outbox pattern — event ditulis bersamaan transaksi bisnis, di-publish ke RabbitMQ oleh Coravel scheduler';
