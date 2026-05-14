-- ═══════════════════════════════════════════════════════════════════════════
--  RENT PAK HAJI — rpk_driver Schema
--  Owner   : Driver Service (.NET)
--  Author  : Rizkalfin Bagas Aminullah
--  Version : 1.0.0  |  May 2026
--
--  Tabel dalam DB ini:
--    1. driver              → Master data sopir
--    2. driver_availability → Jadwal ketersediaan harian (seperti vehicle_standby)
--    3. outbox_message      → Reliable event delivery (Outbox pattern)
--
--  Pola mengikuti rpk_vehicle:
--    ✓ Soft-delete: is_active BOOLEAN
--    ✓ Optimistic concurrency: version INT
--    ✓ Audit: created_by/at, modified_by/at
--    ✓ Denorm: pool_location_name inline
--    ✓ Outbox pattern untuk event publish
-- ═══════════════════════════════════════════════════════════════════════════

\c rpk_driver;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────
-- ENUM TYPES
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE driver_status AS ENUM (
    'AVAILABLE',    -- siap ditugaskan
    'ON_DUTY',      -- sedang mengantar / dalam perjalanan aktif
    'OFF_DUTY',     -- selesai shift, tidak tersedia
    'ON_LEAVE',     -- cuti / izin
    'SUSPENDED',    -- diskors (ada masalah)
    'INACTIVE'      -- tidak aktif / resign
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE sim_type AS ENUM (
    'SIM_A',   -- kendaraan roda 4 pribadi
    'SIM_B1',  -- kendaraan penumpang >8 orang
    'SIM_B2',  -- kendaraan angkutan barang
    'SIM_C'    -- kendaraan roda 2 (motor)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════════
-- TABEL 1: DRIVER
-- Master data sopir. Pola identik dengan master_vehicle:
--   pool_location_id + name (denorm), version, audit, is_active.
-- Driver Service bertanggung jawab atas ketersediaan dan status sopir.
-- Assignment sopir ke booking dihandle rpk_bookingorder (VehicleAssignment).
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS driver (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Identitas
    name                VARCHAR(150)    NOT NULL,
    phone               VARCHAR(20)     UNIQUE NOT NULL,
    email               VARCHAR(150),
    id_number           VARCHAR(30)     UNIQUE NOT NULL,    -- nomor KTP
    photo_url           VARCHAR(500),                       -- foto profil sopir

    -- SIM (Surat Izin Mengemudi)
    sim_number          VARCHAR(30)     UNIQUE NOT NULL,    -- nomor SIM
    sim_type            sim_type        NOT NULL DEFAULT 'SIM_A',
    sim_expiry          DATE            NOT NULL,           -- tanggal expired SIM

    -- Status & lokasi base
    status              driver_status   NOT NULL DEFAULT 'AVAILABLE',
    pool_location_id    UUID            NOT NULL,           -- pool base sopir (cross-service ref)
    pool_location_name  VARCHAR(150)    NOT NULL,           -- [denorm]

    -- Kapabilitas kendaraan
    can_drive_car       BOOLEAN         NOT NULL DEFAULT TRUE,
    can_drive_motorcycle BOOLEAN        NOT NULL DEFAULT FALSE,

    -- Rekam jejak
    total_trips         INT             NOT NULL DEFAULT 0, -- akumulasi jumlah trip selesai
    rating              DECIMAL(3,2),                       -- rata-rata rating dari customer (1.00–5.00)
    rating_count        INT             NOT NULL DEFAULT 0, -- jumlah rating yang masuk

    -- sopir yang bermasalah — diblokir dari penugasan
    is_blocked          BOOLEAN         NOT NULL DEFAULT FALSE,
    blocked_reason      TEXT,

    -- Emergency contact
    emergency_contact_name  VARCHAR(150),
    emergency_contact_phone VARCHAR(20),

    -- Soft delete & audit (pola vehicle)
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    version             INT             NOT NULL DEFAULT 1,     -- optimistic concurrency token
    unique_key          VARCHAR(100),                           -- idempotency key
    created_by          UUID            NOT NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ,
    transaction_id      VARCHAR(100)                            -- saga/event correlation ID
);

CREATE INDEX IF NOT EXISTS idx_drv_status   ON driver(status);
CREATE INDEX IF NOT EXISTS idx_drv_pool     ON driver(pool_location_id);
CREATE INDEX IF NOT EXISTS idx_drv_phone    ON driver(phone);
CREATE INDEX IF NOT EXISTS idx_drv_sim      ON driver(sim_number);
CREATE INDEX IF NOT EXISTS idx_drv_active   ON driver(is_active);
CREATE INDEX IF NOT EXISTS idx_drv_car      ON driver(can_drive_car) WHERE can_drive_car = TRUE;
CREATE INDEX IF NOT EXISTS idx_drv_moto     ON driver(can_drive_motorcycle) WHERE can_drive_motorcycle = TRUE;

COMMENT ON TABLE driver IS 'Master data sopir — identitas, SIM, pool base, status ketersediaan. Mengikuti pola rpk_vehicle: version, audit, denorm pool, is_active';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 2: DRIVER_AVAILABILITY
-- Jadwal ketersediaan sopir per hari / per periode.
-- Analog dengan vehicle_standby: sopir di-block untuk kebutuhan tertentu.
-- Berguna untuk operasi Haji: sopir sudah di-pre-assign ke kloter.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS driver_availability (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),

    driver_id           UUID        NOT NULL,               -- ref ke driver (same DB)
    driver_name         VARCHAR(150) NOT NULL,              -- [denorm]
    driver_phone        VARCHAR(20) NOT NULL,               -- [denorm]

    -- Apakah tersedia atau diblok
    -- TRUE = tersedia pada period ini, FALSE = tidak tersedia (libur, pre-assign, dll)
    is_available        BOOLEAN     NOT NULL DEFAULT TRUE,

    -- Period ketersediaan
    available_date      DATE        NOT NULL,
    shift_start         TIME,       -- null = seharian
    shift_end           TIME,

    -- Alasan tidak tersedia (jika is_available = FALSE)
    unavailability_reason VARCHAR(100),
    -- e.g. CUTI, PRE_ASSIGNED, MAINTENANCE_DUTY, OFF_DUTY

    -- Referensi booking jika sudah di-pre-assign (opsional)
    booking_order_id    UUID,
    booking_code        VARCHAR(20),                        -- [denorm]

    pool_location_id    UUID        NOT NULL,
    pool_location_name  VARCHAR(150) NOT NULL,              -- [denorm]

    notes               TEXT,
    created_by          UUID        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ,

    UNIQUE(driver_id, available_date, shift_start)
);

CREATE INDEX IF NOT EXISTS idx_da_driver    ON driver_availability(driver_id);
CREATE INDEX IF NOT EXISTS idx_da_date      ON driver_availability(available_date);
CREATE INDEX IF NOT EXISTS idx_da_pool      ON driver_availability(pool_location_id);
CREATE INDEX IF NOT EXISTS idx_da_avail     ON driver_availability(is_available, available_date);

COMMENT ON TABLE driver_availability IS 'Jadwal ketersediaan sopir per hari — analog dengan vehicle_standby. Untuk pre-assign sopir ke kloter Haji atau block cuti';

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
