-- ═══════════════════════════════════════════════════════════════════════════
--  RENT PAK HAJI — rpk_master Schema (Enhanced)
--  Author  : Rizkalfin Bagas Aminullah
--  Version : 2.0.0  |  May 2026
--
--  Tables:
--    ✓ pool_location_type    → klasifikasi tipe pool
--    ✓ pool_location         → hierarki lokasi pool dengan geofence & timezone
--    ✓ customer              → master data customer (termasuk B2B & blocking)
--    ✓ vehicle_driver_pair   → pairing terstruktur sopir-kendaraan dengan approval
--    ✓ vehicle_driver_schedule → jadwal shift per pairing
--    ✓ approval_configuration → engine approval multi-level (reusable)
--    ✓ approval_matrix       → approver per pool dan level
--    ✓ nfc_card              → kartu NFC untuk pool gate tracking
-- ═══════════════════════════════════════════════════════════════════════════

\c rpk_master;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 1: POOL LOCATION TYPE
-- Tipe pool: Main Pool, Sub Pool, Customer Site, Partner Location
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS pool_location_type (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    code        VARCHAR(20) UNIQUE NOT NULL,  -- MAIN_POOL, SUB_POOL, CUSTOMER_SITE, PARTNER
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO pool_location_type (id, code, name, description) VALUES
  (uuid_generate_v4(), 'MAIN_POOL',     'Main Pool',          'Pool utama milik sendiri dengan kapasitas penuh'),
  (uuid_generate_v4(), 'SUB_POOL',      'Sub Pool',           'Pool cabang/sub dari main pool'),
  (uuid_generate_v4(), 'CUSTOMER_SITE', 'Customer Site',      'Lokasi di sisi customer (B2B)'),
  (uuid_generate_v4(), 'PARTNER',       'Partner Location',   'Lokasi mitra/partner pengambilan/pengembalian'),
  (uuid_generate_v4(), 'AIRPORT',       'Airport',            'Lokasi bandara untuk pickup/dropoff'),
  (uuid_generate_v4(), 'EMBARKASI',     'Embarkasi Haji',     'Titik embarkasi jamaah haji')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE pool_location_type IS 'Klasifikasi tipe pool location: Main Pool, Sub Pool, Customer Site, Partner, Airport, Embarkasi';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 2: POOL LOCATION (ENHANCED)
-- Hierarki pool dengan geofence, timezone, dan jam operasional.
-- Parent-child self-reference: main pool → sub pool.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS pool_location (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    code                VARCHAR(20)     UNIQUE,                 -- kode lokasi (opsional untuk sub-pool)
    name                VARCHAR(150)    NOT NULL,
    address             TEXT            NOT NULL,
    address_detail      TEXT,                                   -- detail alamat tambahan

    -- tipe pool
    pool_type_id        UUID            REFERENCES pool_location_type(id),
    pool_type_code      VARCHAR(20),                            -- [denorm]
    pool_type_name      VARCHAR(100),                           -- [denorm]

    -- hierarki: main pool → sub pool (self-reference)
    parent_pool_id      UUID            REFERENCES pool_location(id),
    parent_pool_name    VARCHAR(150),                           -- [denorm]

    -- Kapasitas
    capacity            INT             NOT NULL DEFAULT 0,
    current_occupancy   INT             NOT NULL DEFAULT 0,

    -- Geolokasi & geofence
    latitude            DECIMAL(11,8)   NOT NULL DEFAULT 0,
    longitude           DECIMAL(11,8)   NOT NULL DEFAULT 0,
    radius              INT             DEFAULT 200,            -- geofence radius dalam meter

    -- timezone offset (WIB=7, WITA=8, WIT=9)
    time_offset         INT             NOT NULL DEFAULT 7,
    timezone_name       VARCHAR(60)     NOT NULL DEFAULT 'Asia/Jakarta',

    -- jam operasional dalam JSON
    -- Format: {"mon":"07:00-21:00","tue":"07:00-21:00",...,"sun":"08:00-18:00"}
    working_hour        JSONB,

    -- apakah pool ini sebagai stok kendaraan
    is_stock_pool       BOOLEAN         NOT NULL DEFAULT FALSE,

    -- tipe check-in/check-out: 1=entry_only, 2=exit_only, 3=both
    cico_pool_type      INT,

    -- status sinkronisasi ke sistem eksternal
    sync_status         SMALLINT        NOT NULL DEFAULT 0,

    -- Gate/NFC info
    has_nfc_gate        BOOLEAN         NOT NULL DEFAULT FALSE, -- apakah pool ini punya NFC gate
    gate_count          INT             NOT NULL DEFAULT 0,

    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    version             INT             NOT NULL DEFAULT 1,     -- optimistic concurrency token
    unique_key          VARCHAR(100),                           -- idempotency key
    created_by          UUID            NOT NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ,
    transaction_id      VARCHAR(100)                            -- saga/event correlation ID
);

CREATE INDEX IF NOT EXISTS idx_pl_parent ON pool_location(parent_pool_id);
CREATE INDEX IF NOT EXISTS idx_pl_type ON pool_location(pool_type_id);
CREATE INDEX IF NOT EXISTS idx_pl_active ON pool_location(is_active);
COMMENT ON TABLE pool_location IS 'Pool location dengan hierarki parent-child, geofence radius, timezone, jam operasional, dan tipe pool';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 3: CUSTOMER (ENHANCED)
-- Master data customer — termasuk flag B2B dan pemblokiran
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS customer (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(150)    NOT NULL,
    phone           VARCHAR(20)     UNIQUE NOT NULL,
    email           VARCHAR(150)    UNIQUE,
    id_number       VARCHAR(30)     UNIQUE NOT NULL,
    id_type         VARCHAR(10)     NOT NULL CHECK (id_type IN ('KTP','SIM','PASSPORT')),
    address         TEXT,

    -- customer yang diblokir dari pemesanan
    is_blocked      BOOLEAN         NOT NULL DEFAULT FALSE,
    blocked_reason  TEXT,                                       -- alasan pemblokiran

    -- customer korporat/B2B
    is_b2b          BOOLEAN         NOT NULL DEFAULT FALSE,
    company_name    VARCHAR(150),                               -- nama perusahaan (jika B2B)
    company_code    VARCHAR(50),                                -- kode perusahaan
    npwp            VARCHAR(25),                                -- NPWP perusahaan (B2B)

    -- logo untuk tampilan dashboard B2B
    customer_logo   VARCHAR(500),

    -- Audit
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    version         INT             NOT NULL DEFAULT 1,
    unique_key      VARCHAR(100),
    created_by      UUID            NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by     UUID,
    modified_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_cust_phone ON customer(phone);
CREATE INDEX IF NOT EXISTS idx_cust_b2b ON customer(is_b2b);
CREATE INDEX IF NOT EXISTS idx_cust_blocked ON customer(is_blocked);
COMMENT ON TABLE customer IS 'Customer master — termasuk flag isBlocked, isB2B, dan company info untuk customer korporat';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 4: VEHICLE DRIVER PAIR
-- Pairing struktural antara sopir dan kendaraan, dengan approval workflow.
-- Berguna untuk operasi Haji (sopir tetap per armada) dan kontrak B2B sopir dedicated.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_driver_pair (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Kendaraan (cross-service ref — no FK)
    vehicle_id          UUID        NOT NULL,                   -- ref ke rpk_vehicle.master_vehicle
    vin                 VARCHAR(20),                            -- [denorm]
    license_plate       VARCHAR(15) NOT NULL,                   -- [denorm]
    vehicle_type        VARCHAR(20) NOT NULL,                   -- [denorm]
    vehicle_type_name   VARCHAR(100),                           -- [denorm]

    -- Driver 1 (utama)
    driver1_id          UUID        NOT NULL,                   -- ref ke rpk_driver.driver
    driver1_name        VARCHAR(150) NOT NULL,                  -- [denorm]
    driver1_phone       VARCHAR(20),                            -- [denorm] kontak cepat
    driver1_license_no  VARCHAR(30),                            -- [denorm] nomor SIM

    -- Driver 2 (cadangan)
    driver2_id          UUID,
    driver2_name        VARCHAR(150),
    driver2_phone       VARCHAR(20),

    -- Periode pairing
    start_period        DATE        NOT NULL,
    end_period          DATE,                                   -- null = aktif tanpa batas

    -- apakah pairing ini aktif/hadir hari ini
    is_present          BOOLEAN     NOT NULL DEFAULT TRUE,

    -- Pool assignment
    pool_location_id    UUID        NOT NULL,                   -- pool base untuk pairing ini
    pool_location_name  VARCHAR(150) NOT NULL,                  -- [denorm]

    -- Approval workflow
    approval_status     VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                        CHECK (approval_status IN ('PENDING','APPROVED','REJECTED','CANCELLED')),

    notes               TEXT,
    transaction_id      VARCHAR(100),                           -- saga/event correlation ID
    status              SMALLINT    NOT NULL DEFAULT 1,
    created_by          UUID        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_vdp_vehicle ON vehicle_driver_pair(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vdp_driver1 ON vehicle_driver_pair(driver1_id);
CREATE INDEX IF NOT EXISTS idx_vdp_pool ON vehicle_driver_pair(pool_location_id);
CREATE INDEX IF NOT EXISTS idx_vdp_period ON vehicle_driver_pair(start_period, end_period);
COMMENT ON TABLE vehicle_driver_pair IS 'Pairing terstruktur sopir-kendaraan dengan approval workflow — berguna untuk operasi Haji dan kontrak B2B sopir dedicated';

-- Jadwal shift untuk pairing sopir-kendaraan
CREATE TABLE IF NOT EXISTS vehicle_driver_schedule (
    id                      UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_driver_pair_id  UUID        NOT NULL REFERENCES vehicle_driver_pair(id) ON DELETE CASCADE,
    schedule_date           DATE        NOT NULL,
    shift_start             TIME        NOT NULL,
    shift_end               TIME        NOT NULL,
    assigned_driver_id      UUID        NOT NULL,   -- driver1 atau driver2
    assigned_driver_name    VARCHAR(150) NOT NULL,
    booking_id              UUID,                   -- jika jadwal ini terkait booking spesifik
    notes                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vds_pair ON vehicle_driver_schedule(vehicle_driver_pair_id);
CREATE INDEX IF NOT EXISTS idx_vds_date ON vehicle_driver_schedule(schedule_date);
COMMENT ON TABLE vehicle_driver_schedule IS 'Jadwal shift per hari untuk pairing sopir-kendaraan';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 5: APPROVAL ENGINE (REUSABLE)
-- Engine approval multi-level yang reusable untuk:
--   - Transfer kendaraan antar pool (vehicle_transfer)
--   - Perubahan kontrak B2B
--   - Override harga special
--   - Driver-vehicle pairing
-- ═══════════════════════════════════════════════════════════════

-- Konfigurasi approval per tipe flow
CREATE TABLE IF NOT EXISTS approval_configuration (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    code            VARCHAR(50) UNIQUE NOT NULL,    -- VEHICLE_TRANSFER, CONTRACT_CHANGE, DRIVER_PAIR, PRICE_OVERRIDE
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    approval_type   SMALLINT    NOT NULL DEFAULT 1, -- 1=sequential, 2=parallel
    max_level       INT         NOT NULL DEFAULT 1, -- maksimal level approval
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID        NOT NULL,
    modified_at     TIMESTAMPTZ,
    modified_by     UUID,
    transaction_id  VARCHAR(100)
);

INSERT INTO approval_configuration (id, code, name, description, max_level, created_by) VALUES
  (uuid_generate_v4(), 'VEHICLE_TRANSFER',  'Transfer Kendaraan Antar Pool', 'Approval untuk pemindahan kendaraan antar pool', 2, '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'CONTRACT_CHANGE',   'Perubahan Kontrak B2B',         'Approval untuk amandemen kontrak customer korporat', 2, '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'DRIVER_PAIR',       'Pairing Sopir-Kendaraan',       'Approval untuk assignment sopir ke kendaraan', 1, '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'PRICE_OVERRIDE',    'Override Harga Khusus',         'Approval untuk penetapan harga diluar special price', 1, '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE approval_configuration IS 'Konfigurasi workflow approval per tipe flow: VEHICLE_TRANSFER, CONTRACT_CHANGE, DRIVER_PAIR, PRICE_OVERRIDE';

-- Matrix approver per pool/role
CREATE TABLE IF NOT EXISTS approval_matrix (
    id                          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    approval_configuration_id   UUID        NOT NULL REFERENCES approval_configuration(id),
    approval_configuration_code VARCHAR(50) NOT NULL,   -- [denorm]

    -- Scope: pool mana yang berlaku
    pool_location_id            UUID,                   -- null = berlaku global
    pool_location_name          VARCHAR(150),           -- [denorm]

    -- Approver
    role_id                     INT         NOT NULL,   -- role ID di sistem auth
    role_name                   VARCHAR(100) NOT NULL,  -- [denorm]
    approver_user_id            UUID,                   -- user spesifik (opsional)
    approver_name               VARCHAR(150),           -- [denorm]

    -- Level dalam approval chain
    approval_level              INT         NOT NULL DEFAULT 1,  -- 1=first approver, 2=second, dll
    category_type               SMALLINT    NOT NULL DEFAULT 1,

    status                      SMALLINT    NOT NULL DEFAULT 1,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by                  UUID        NOT NULL,
    modified_at                 TIMESTAMPTZ,
    modified_by                 UUID,
    transaction_id              VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_am_config ON approval_matrix(approval_configuration_id);
CREATE INDEX IF NOT EXISTS idx_am_pool ON approval_matrix(pool_location_id);
COMMENT ON TABLE approval_matrix IS 'Matrix approver multi-level per pool dan tipe approval';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 6: NFC CARD
-- Kartu NFC untuk gate tracking pool — dengan pool location awareness
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS nfc_card (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    card_uid            VARCHAR(50) UNIQUE NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE'
                        CHECK (status IN ('AVAILABLE','ASSIGNED','DISABLED','LOST')),
    assigned_booking_id UUID,
    assigned_vehicle_id UUID,                       -- vehicle yang sedang menggunakan kartu ini
    assigned_at         TIMESTAMPTZ,
    last_scanned_at     TIMESTAMPTZ,
    last_scanned_pool   UUID,                       -- pool terakhir yang scan kartu ini
    last_scanned_gate   VARCHAR(50),                -- gate ID terakhir

    -- pool saat ini kartu berada
    current_pool_id     UUID,
    current_pool_name   VARCHAR(150),               -- [denorm]

    is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
    notes               TEXT,
    created_by          UUID        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_nfc_status ON nfc_card(status);
CREATE INDEX IF NOT EXISTS idx_nfc_booking ON nfc_card(assigned_booking_id);
COMMENT ON TABLE nfc_card IS 'NFC card master — tracking kendaraan dan pool location saat ini untuk keperluan gate scan';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 7: VOUCHER & SPECIAL PRICE (EXISTING — KEPT)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS voucher (
    id                      UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    code                    VARCHAR(50)     UNIQUE NOT NULL,
    name                    VARCHAR(150)    NOT NULL,
    discount_type           VARCHAR(20)     NOT NULL
                            CHECK (discount_type IN ('PERCENTAGE','FIXED_AMOUNT','FREE_DAY')),
    discount_value          DECIMAL(18,2)   NOT NULL,
    max_discount            DECIMAL(18,2),
    max_usage               INT             NOT NULL DEFAULT 1,
    current_usage           INT             NOT NULL DEFAULT 0,
    valid_from              TIMESTAMPTZ     NOT NULL,
    valid_to                TIMESTAMPTZ     NOT NULL,
    min_order_amount        DECIMAL(18,2)   DEFAULT 0,
    single_use_per_customer BOOLEAN         NOT NULL DEFAULT TRUE,

    -- Scope (opsional)
    applicable_vehicle_type VARCHAR(20),    -- null = semua tipe
    applicable_pool_id      UUID,           -- null = semua pool

    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    created_by              UUID            NOT NULL,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by             UUID,
    modified_at             TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS special_price (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(150)    NOT NULL,
    vehicle_type    VARCHAR(20)     NOT NULL,
    vehicle_category VARCHAR(30),
    price_per_day   DECIMAL(18,2)   NOT NULL,
    valid_from      DATE            NOT NULL,
    valid_to        DATE            NOT NULL,
    description     TEXT,
    priority        INT             NOT NULL DEFAULT 0,  -- higher = lebih prioritas
    pool_location_id UUID,                              -- null = semua pool
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_by      UUID            NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by     UUID,
    modified_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sp_dates ON special_price(valid_from, valid_to);
CREATE INDEX IF NOT EXISTS idx_sp_type ON special_price(vehicle_type);

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 8: OUTBOX MESSAGE
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
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_outbox_status ON outbox_message(status, created_at);
