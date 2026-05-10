-- ═══════════════════════════════════════════════════════════════════════════
--  RENT PAK HAJI — rpk_master Schema (Enhanced)
--  Adapted from: SERA AstraFMS 2.0 ServiceMaster
--  Author  : Rizkalfin Bagas Aminullah
--  Version : 2.0.0  |  May 2026
--
--  SERA Patterns adapted:
--    ✓ Location hierarchy    → pool_location (parentLocationId, locationType, geofence)
--    ✓ LocationType          → pool_location_type (lookup tipe pool)
--    ✓ Customer (enhanced)   → customer (isBlocked, isB2B flag dari SERA)
--    ✓ VehicleDriverPair     → vehicle_driver_pair (pairing sopir-kendaraan terstruktur)
--    ✓ VehicleDriverPairSchedule → vehicle_driver_schedule
--    ✓ ApprovalConfiguration → approval_configuration (engine approval reusable)
--    ✓ ApprovalMatrix        → approval_matrix (multi-level approver per pool/role)
--    ✓ NfcCard (enhanced)    → nfc_card (timeOffset, lastPool dari SERA location pattern)
-- ═══════════════════════════════════════════════════════════════════════════

\c rpk_master;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 1: POOL LOCATION TYPE
-- [SERA adaptation: LocationType]
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

COMMENT ON TABLE pool_location_type IS 'SERA adaptation: LocationType — klasifikasi tipe pool location';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 2: POOL LOCATION (ENHANCED)
-- [SERA adaptation: Location] — tambah hierarchy, geofence, timeOffset, workingHour
-- SERA menyimpan parent-child hierarchy via parentLocationId (self-ref)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS pool_location (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    code                VARCHAR(20)     UNIQUE,                 -- [SERA: locationCode] opsional untuk sub-pool
    name                VARCHAR(150)    NOT NULL,
    address             TEXT            NOT NULL,
    address_detail      TEXT,                                   -- [SERA: locationAddressDetail]

    -- [SERA: locationTypeId] — tipe pool
    pool_type_id        UUID            REFERENCES pool_location_type(id),
    pool_type_code      VARCHAR(20),                            -- [SERA denorm]
    pool_type_name      VARCHAR(100),                           -- [SERA denorm]

    -- [SERA: parentLocationId] — hierarchy: main pool → sub pool
    parent_pool_id      UUID            REFERENCES pool_location(id),
    parent_pool_name    VARCHAR(150),                           -- [SERA denorm]

    -- Kapasitas
    capacity            INT             NOT NULL DEFAULT 0,
    current_occupancy   INT             NOT NULL DEFAULT 0,

    -- Geolokasi & geofence
    latitude            DECIMAL(11,8)   NOT NULL DEFAULT 0,
    longitude           DECIMAL(11,8)   NOT NULL DEFAULT 0,
    radius              INT             DEFAULT 200,            -- [SERA: radius] geofence dalam meter

    -- [SERA: timeOffset] — timezone offset (WIB=7, WITA=8, WIT=9)
    time_offset         INT             NOT NULL DEFAULT 7,
    timezone_name       VARCHAR(60)     NOT NULL DEFAULT 'Asia/Jakarta',  -- e.g. Asia/Jakarta

    -- [SERA: workingHour] — jam operasional dalam JSON
    -- Format: {"mon":"07:00-21:00","tue":"07:00-21:00",...,"sun":"08:00-18:00"}
    working_hour        JSONB,

    -- [SERA: vehicleStockFlag] — apakah pool ini sebagai stok kendaraan
    is_stock_pool       BOOLEAN         NOT NULL DEFAULT FALSE,

    -- [SERA: cicoPoolType] — tipe check-in/check-out
    cico_pool_type      INT,   -- 1=entry_only, 2=exit_only, 3=both

    -- [SERA: syncStatus] — status sync ke sistem eksternal
    sync_status         SMALLINT        NOT NULL DEFAULT 0,

    -- Gate/NFC info
    has_nfc_gate        BOOLEAN         NOT NULL DEFAULT FALSE, -- apakah pool ini punya NFC gate
    gate_count          INT             NOT NULL DEFAULT 0,

    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    version             INT             NOT NULL DEFAULT 1,     -- [SERA: version] optimistic concurrency
    unique_key          VARCHAR(100),                           -- [SERA: uniqueKey] idempotency
    created_by          UUID            NOT NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ,
    transaction_id      VARCHAR(100)                            -- [SERA: transactionId]
);

CREATE INDEX IF NOT EXISTS idx_pl_parent ON pool_location(parent_pool_id);
CREATE INDEX IF NOT EXISTS idx_pl_type ON pool_location(pool_type_id);
CREATE INDEX IF NOT EXISTS idx_pl_active ON pool_location(is_active);
COMMENT ON TABLE pool_location IS 'SERA adaptation: Location — pool location dengan hierarchy (parent-child), geofence, timezone, dan tipe pool';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 3: CUSTOMER (ENHANCED)
-- [SERA adaptation: Customer] — tambah isBlocked, isB2B dari SERA
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS customer (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(150)    NOT NULL,
    phone           VARCHAR(20)     UNIQUE NOT NULL,
    email           VARCHAR(150)    UNIQUE,
    id_number       VARCHAR(30)     UNIQUE NOT NULL,
    id_type         VARCHAR(10)     NOT NULL CHECK (id_type IN ('KTP','SIM','PASSPORT')),
    address         TEXT,

    -- [SERA: isBlocked] — customer diblokir dari pemesanan
    is_blocked      BOOLEAN         NOT NULL DEFAULT FALSE,
    blocked_reason  TEXT,                                       -- alasan pemblokiran

    -- [SERA: isB2B] — customer korporat/B2B
    is_b2b          BOOLEAN         NOT NULL DEFAULT FALSE,
    company_name    VARCHAR(150),                               -- nama perusahaan (jika B2B)
    company_code    VARCHAR(50),                                -- kode perusahaan
    npwp            VARCHAR(25),                                -- NPWP perusahaan (B2B)

    -- [SERA: customerLogo] — untuk tampilan di dashboard B2B
    customer_logo   VARCHAR(500),

    -- Audit [SERA pattern]
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
COMMENT ON TABLE customer IS 'Customer master — enhanced dengan isBlocked, isB2B, company info dari SERA ServiceMaster pattern';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 4: VEHICLE DRIVER PAIR
-- [SERA adaptation: VehicleDriverPair + VehicleDriverPairSchedule]
-- Pairing struktural antara sopir dan kendaraan, dengan approval workflow
-- Lebih terstruktur dari DriverAssignment yang ada di rpk_journey
-- Berguna untuk: operasi Haji (sopir tetap per armada), kontrak B2B dengan sopir dedicated
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_driver_pair (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Kendaraan ([SERA: vehicleId, vin, licensePlate, vehicleTypeId] — cross-service ref)
    vehicle_id          UUID        NOT NULL,                   -- ref ke rpk_vehicle.master_vehicle
    vin                 VARCHAR(20),                            -- [SERA denorm]
    license_plate       VARCHAR(15) NOT NULL,                   -- [SERA denorm]
    vehicle_type        VARCHAR(20) NOT NULL,                   -- [SERA denorm: vehicleTypeName]
    vehicle_type_name   VARCHAR(100),                           -- [SERA denorm]

    -- Driver 1 (utama) [SERA: driver1Id, driver1Nrp, driver1Name]
    driver1_id          UUID        NOT NULL,                   -- ref ke rpk_driver.driver
    driver1_name        VARCHAR(150) NOT NULL,                  -- [SERA denorm]
    driver1_phone       VARCHAR(20),                            -- denorm untuk kontak cepat
    driver1_license_no  VARCHAR(30),                            -- denorm: nomor SIM

    -- Driver 2 (cadangan) [SERA: driver2Id, driver2Nrp, driver2Name]
    driver2_id          UUID,
    driver2_name        VARCHAR(150),
    driver2_phone       VARCHAR(20),

    -- Periode pairing [SERA: startPeriod, endPeriod]
    start_period        DATE        NOT NULL,
    end_period          DATE,                                   -- null = aktif tanpa batas

    -- [SERA: setPresent] — apakah pairing ini aktif/hadir hari ini
    is_present          BOOLEAN     NOT NULL DEFAULT TRUE,

    -- Pool assignment ([SERA: locationId, locationName])
    pool_location_id    UUID        NOT NULL,                   -- pool base untuk pairing ini
    pool_location_name  VARCHAR(150) NOT NULL,                  -- [SERA denorm]

    -- Approval workflow [SERA: approvalStatus]
    approval_status     VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                        CHECK (approval_status IN ('PENDING','APPROVED','REJECTED','CANCELLED')),

    notes               TEXT,
    transaction_id      VARCHAR(100),                           -- [SERA: transactionId]
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
COMMENT ON TABLE vehicle_driver_pair IS 'SERA adaptation: VehicleDriverPair — pairing terstruktur sopir-kendaraan dengan approval workflow (untuk operasi Haji/kontrak B2B)';

-- Jadwal shift untuk pairing [SERA: VehicleDriverPairSchedule]
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
COMMENT ON TABLE vehicle_driver_schedule IS 'SERA adaptation: VehicleDriverPairSchedule — jadwal shift per hari untuk pairing sopir-kendaraan';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 5: APPROVAL ENGINE (REUSABLE)
-- [SERA adaptation: ApprovalConfiguration + ApprovalMatrix]
-- Engine approval multi-level yang reusable untuk:
--   - Transfer kendaraan antar pool (vehicle_transfer)
--   - Perubahan kontrak B2B
--   - Override harga special
--   - Driver-vehicle pairing
-- ═══════════════════════════════════════════════════════════════

-- Konfigurasi approval per tipe flow [SERA: ApprovalConfiguration]
CREATE TABLE IF NOT EXISTS approval_configuration (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    code            VARCHAR(50) UNIQUE NOT NULL,    -- VEHICLE_TRANSFER, CONTRACT_CHANGE, DRIVER_PAIR, PRICE_OVERRIDE
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    approval_type   SMALLINT    NOT NULL DEFAULT 1, -- [SERA: approvalType] 1=sequential, 2=parallel
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

COMMENT ON TABLE approval_configuration IS 'SERA adaptation: ApprovalConfiguration — konfigurasi workflow approval per tipe flow';

-- Matrix approver per pool/role [SERA: ApprovalMatrix]
CREATE TABLE IF NOT EXISTS approval_matrix (
    id                          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    approval_configuration_id   UUID        NOT NULL REFERENCES approval_configuration(id),
    approval_configuration_code VARCHAR(50) NOT NULL,   -- [SERA denorm]

    -- Scope: pool mana yang berlaku
    pool_location_id            UUID,                   -- null = berlaku global
    pool_location_name          VARCHAR(150),           -- [SERA denorm]

    -- Approver [SERA: roleId, roleName]
    role_id                     INT         NOT NULL,   -- role ID di sistem auth
    role_name                   VARCHAR(100) NOT NULL,  -- [SERA denorm: roleName]
    approver_user_id            UUID,                   -- user spesifik (opsional)
    approver_name               VARCHAR(150),           -- [SERA denorm]

    -- Level dalam chain [SERA: approvalLevel]
    approval_level              INT         NOT NULL DEFAULT 1,  -- 1=first approver, 2=second, dll
    category_type               SMALLINT    NOT NULL DEFAULT 1,  -- [SERA: categoryType]

    status                      SMALLINT    NOT NULL DEFAULT 1,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by                  UUID        NOT NULL,
    modified_at                 TIMESTAMPTZ,
    modified_by                 UUID,
    transaction_id              VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_am_config ON approval_matrix(approval_configuration_id);
CREATE INDEX IF NOT EXISTS idx_am_pool ON approval_matrix(pool_location_id);
COMMENT ON TABLE approval_matrix IS 'SERA adaptation: ApprovalMatrix — matrix approver multi-level per pool dan tipe approval';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 6: NFC CARD (EXISTING — ENHANCED)
-- Tambah field timeOffset dari SERA pattern
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

    -- Dari SERA: pool tracking
    current_pool_id     UUID,                       -- pool saat ini kartu berada
    current_pool_name   VARCHAR(150),               -- [SERA denorm]

    is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
    notes               TEXT,
    created_by          UUID        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_nfc_status ON nfc_card(status);
CREATE INDEX IF NOT EXISTS idx_nfc_booking ON nfc_card(assigned_booking_id);
COMMENT ON TABLE nfc_card IS 'NFC card master — enhanced dengan vehicle tracking dan pool location dari SERA pattern';

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
