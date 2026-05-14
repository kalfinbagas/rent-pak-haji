-- ═══════════════════════════════════════════════════════════════════════════
--  RENT PAK HAJI — rpk_vehicle Schema
--  Author  : Rizkalfin Bagas Aminullah
--  Version : 2.0.0  |  May 2026
--
--  Tables:
--    ✓ vehicle_category          → lookup kategori kendaraan
--    ✓ vehicle_transmission_type → lookup tipe transmisi
--    ✓ master_vehicle            → data utama kendaraan
--    ✓ vehicle_movement          → full audit trail perubahan status/lokasi
--    ✓ vehicle_preparation       → pre-dispatch checklist
--    ✓ vehicle_transfer          → transfer kendaraan antar pool
--    ✓ vehicle_transfer_detail   → detail per unit dalam transfer
--    ✓ vehicle_transfer_approval → multi-level approval transfer
--    ✓ vehicle_pool_allocation   → kuota kendaraan per pool per periode
--    ✓ pool_in_out_dashboard     → agregasi dashboard harian
--    ✓ vehicle_standby           → pre-assign kendaraan untuk booking
--    ✓ vehicle_standby_mapping   → mapping unit spesifik ke standby
--    ✓ vehicle_soft_booking      → replikasi dari rpk_bookingorder (stock hold)
--    ✓ vehicle_assignment        → replikasi dari rpk_bookingorder (dispatch info)
--    ✓ outbox_message            → reliable event delivery
-- ═══════════════════════════════════════════════════════════════════════════

\c rpk_vehicle;

-- ─────────────────────────────────────────────────────────────
-- EXTENSIONS
-- ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for LIKE search optimization

-- ─────────────────────────────────────────────────────────────
-- ENUM TYPES
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE vehicle_status_enum AS ENUM (
    'AVAILABLE',        -- siap disewa
    'RESERVED',         -- soft-booked (menunggu pembayaran)
    'READY',            -- sudah diassign, menunggu dispatch
    'IN_USE',           -- sedang dalam order aktif
    'RETURNING_SOON',   -- mendekati waktu kembali
    'LATE_RETURN',      -- melewati jadwal kembali
    'MAINTENANCE',      -- servis / perawatan rutin
    'BREAKDOWN',        -- mogok / kerusakan mendadak di lapangan
    'THEFT',            -- dilaporkan hilang / dicuri
    'BORROW',           -- dipinjam internal (bukan order customer)
    'INACTIVE'          -- non-aktif / disposal
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE transfer_status_enum AS ENUM (
    'DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'REJECTED',
    'IN_TRANSIT', 'COMPLETED', 'CANCELLED'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE preparation_status_enum AS ENUM (
    'PENDING', 'IN_PROGRESS', 'COMPLETED', 'SKIPPED'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 1: LOOKUP / REFERENCE TABLES
-- Setiap lookup punya: code, name, is_active, version, audit
-- ═══════════════════════════════════════════════════════════════

-- vehicle_category — disimpan sebagai FK lookup terpisah (bukan VARCHAR inline)
CREATE TABLE IF NOT EXISTS vehicle_category (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    code            VARCHAR(20)     UNIQUE NOT NULL,  -- e.g. SUV, MPV, CITY_CAR, SPORT, MATIC, BEBEK
    name            VARCHAR(100)    NOT NULL,
    vehicle_type    VARCHAR(20)     NOT NULL CHECK (vehicle_type IN ('CAR', 'MOTORCYCLE')),
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    version         INT             NOT NULL DEFAULT 1,
    created_by      UUID            NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by     UUID,
    modified_at     TIMESTAMPTZ
);
COMMENT ON TABLE vehicle_category IS 'Lookup kategori kendaraan (SUV, MPV, City Car, Matic, Bebek, dll)';

-- vehicle_transmission_type
CREATE TABLE IF NOT EXISTS vehicle_transmission_type (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    code            VARCHAR(20)     UNIQUE NOT NULL, -- MANUAL, AUTOMATIC, CVT, DCT
    name            VARCHAR(50)     NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    version         INT             NOT NULL DEFAULT 1,
    created_by      UUID            NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by     UUID,
    modified_at     TIMESTAMPTZ
);
COMMENT ON TABLE vehicle_transmission_type IS 'Lookup tipe transmisi kendaraan (Manual, Automatic, CVT, DCT, AMT)';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 2: MASTER VEHICLE
-- Tabel utama kendaraan — FK ke lookup tables category & transmission
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS master_vehicle (
    -- Primary key
    id                          UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Identifikasi kendaraan
    license_plate               VARCHAR(15)     UNIQUE NOT NULL,
    vin                         VARCHAR(20)     UNIQUE,                     -- Vehicle Identification Number
    vehicle_type                VARCHAR(20)     NOT NULL CHECK (vehicle_type IN ('CAR', 'MOTORCYCLE')),
    brand                       VARCHAR(50)     NOT NULL,
    model                       VARCHAR(50)     NOT NULL,
    year                        INT             NOT NULL,
    color                       VARCHAR(30),

    -- FK ke lookup tables
    vehicle_category_id         UUID            REFERENCES vehicle_category(id),
    transmission_type_id        UUID            REFERENCES vehicle_transmission_type(id),
    number_of_seats             INT,                                         -- jumlah kursi
    number_of_doors             INT,
    fuel_type                   VARCHAR(20)     DEFAULT 'GASOLINE'
                                CHECK (fuel_type IN ('GASOLINE','DIESEL','ELECTRIC','HYBRID')),
    wheel_drive                 VARCHAR(10)     DEFAULT '2WD'
                                CHECK (wheel_drive IN ('2WD','4WD','AWD')),

    -- Status & lokasi
    status                      vehicle_status_enum NOT NULL DEFAULT 'AVAILABLE',
    pool_location_id            UUID            NOT NULL,                    -- cross-service ref ke rpk_master.pool_location
    pool_location_name          VARCHAR(150)    NOT NULL,                    -- [denorm]

    -- Pricing
    daily_rate                  DECIMAL(18,2)   NOT NULL,

    -- Odometer & kondisi
    odometer                    INT             NOT NULL DEFAULT 0,
    has_obd                     BOOLEAN         NOT NULL DEFAULT FALSE,      -- apakah punya perangkat OBD

    -- status persiapan sebelum dispatch
    preparation_status          preparation_status_enum DEFAULT NULL,
    preparation_activity        VARCHAR(100),                                -- aktivitas prep saat ini
    preparation_activity_status VARCHAR(20),                                 -- status aktivitas (IN_PROGRESS/DONE)
    preparation_pic             UUID,                                        -- PIC yang bertanggung jawab prep

    -- kondisi kendaraan
    condition_in_maintenance    BOOLEAN         NOT NULL DEFAULT FALSE,
    condition_has_breakdown     BOOLEAN         NOT NULL DEFAULT FALSE,
    condition_has_outstanding   BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Pool scheduling
    pool_in_target_time         TIMESTAMPTZ,    -- kapan target kendaraan masuk pool
    pool_in_actual_time         TIMESTAMPTZ,    -- kapan aktual kendaraan masuk pool

    -- Ownership & kontrak
    ownership_type              VARCHAR(20)     NOT NULL DEFAULT 'OWN'
                                CHECK (ownership_type IN ('OWN','LEASE','PARTNER')),
    valid_from                  DATE,
    valid_to                    DATE,
    acquisition_date            DATE,
    acquisition_value           DECIMAL(18,2),

    -- Referensi sistem eksternal (ERP/SAP)
    external_ref                VARCHAR(100),
    transaction_id              VARCHAR(100),                                -- saga/event correlation ID

    -- Soft delete & audit
    is_active                   BOOLEAN         NOT NULL DEFAULT TRUE,
    version                     INT             NOT NULL DEFAULT 1,          -- optimistic concurrency token
    created_by                  UUID            NOT NULL,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by                 UUID,
    modified_at                 TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_mv_status ON master_vehicle(status);
CREATE INDEX IF NOT EXISTS idx_mv_pool ON master_vehicle(pool_location_id);
CREATE INDEX IF NOT EXISTS idx_mv_type ON master_vehicle(vehicle_type);
CREATE INDEX IF NOT EXISTS idx_mv_category ON master_vehicle(vehicle_category_id);
CREATE INDEX IF NOT EXISTS idx_mv_plate ON master_vehicle(license_plate);
COMMENT ON TABLE master_vehicle IS 'Tabel utama kendaraan — FK ke lookup category & transmission, audit trail, soft-delete, optimistic concurrency';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 3: VEHICLE MOVEMENT (FULL AUDIT TRAIL)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_movement (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id          UUID            NOT NULL REFERENCES master_vehicle(id),
    previous_status     vehicle_status_enum,
    new_status          vehicle_status_enum NOT NULL,
    from_pool_id        UUID,
    from_pool_name      VARCHAR(150),                   -- [denorm]
    to_pool_id          UUID,
    to_pool_name        VARCHAR(150),                   -- [denorm]
    booking_id          UUID,                           -- reference ke rpk_bookingorder
    booking_code        VARCHAR(20),                    -- [denorm] untuk tracing tanpa join
    changed_by          UUID            NOT NULL,
    changed_by_type     VARCHAR(20)     NOT NULL        -- SYSTEM, OPERATOR, CUSTOMER, SCHEDULER
                        CHECK (changed_by_type IN ('SYSTEM','OPERATOR','CUSTOMER','SCHEDULER')),
    -- tipe movement
    movement_type       VARCHAR(30)     NOT NULL DEFAULT 'STATUS_CHANGE'
                        CHECK (movement_type IN (
                          'STATUS_CHANGE','DISPATCH','RETURN','TRANSFER',
                          'MAINTENANCE_IN','MAINTENANCE_OUT','ALLOCATION'
                        )),
    -- sumber trigger movement
    movement_source     VARCHAR(30)     NOT NULL DEFAULT 'MANUAL'
                        CHECK (movement_source IN (
                          'MANUAL','BOOKING_ORDER','NFC_GATE',
                          'SCHEDULER','TRANSFER_REQUEST','API'
                        )),
    reason              VARCHAR(200)    NOT NULL,
    odometer_at         INT,                            -- odometer saat movement
    notes               TEXT,
    -- saga/event correlation ID
    transaction_id      VARCHAR(100),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vm_vehicle ON vehicle_movement(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vm_booking ON vehicle_movement(booking_id);
CREATE INDEX IF NOT EXISTS idx_vm_created ON vehicle_movement(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vm_type ON vehicle_movement(movement_type);
COMMENT ON TABLE vehicle_movement IS 'Full audit trail setiap perubahan status/lokasi kendaraan — tipe movement, sumber trigger, dan saga correlation';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 4: VEHICLE PREPARATION
-- Pre-dispatch checklist sebelum kendaraan diberikan ke customer
-- Tracking: cuci, inspeksi, pengisian BBM, NFC assignment, dokumentasi
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_preparation (
    id                      UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id              UUID        NOT NULL REFERENCES master_vehicle(id),
    booking_id              UUID        NOT NULL,       -- reference ke rpk_bookingorder
    booking_code            VARCHAR(20) NOT NULL,       -- [denorm]
    dispatch_id             UUID,                       -- reference ke rpk_journey.dispatch
    pic_id                  UUID        NOT NULL,       -- operator yang bertanggung jawab
    pic_name                VARCHAR(150) NOT NULL,      -- [denorm] preparation PIC

    -- Status persiapan keseluruhan
    overall_status          preparation_status_enum NOT NULL DEFAULT 'PENDING',

    -- Checklist aktivitas
    is_washed               BOOLEAN     NOT NULL DEFAULT FALSE,
    wash_completed_at       TIMESTAMPTZ,
    is_inspected            BOOLEAN     NOT NULL DEFAULT FALSE,
    inspection_completed_at TIMESTAMPTZ,
    is_fueled               BOOLEAN     NOT NULL DEFAULT FALSE,
    fuel_completed_at       TIMESTAMPTZ,
    is_nfc_assigned         BOOLEAN     NOT NULL DEFAULT FALSE,
    nfc_assigned_at         TIMESTAMPTZ,
    nfc_card_uid            VARCHAR(50),                -- NFC card yang di-assign
    is_document_checked     BOOLEAN     NOT NULL DEFAULT FALSE,
    document_checked_at     TIMESTAMPTZ,

    -- Estimasi & aktual
    estimated_ready_at      TIMESTAMPTZ,               -- kapan diperkirakan siap
    actual_ready_at         TIMESTAMPTZ,               -- kapan benar-benar siap

    notes                   TEXT,
    transaction_id          VARCHAR(100),               -- saga/event correlation ID

    -- Audit
    created_by              UUID        NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID,
    modified_at             TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_vp_vehicle ON vehicle_preparation(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vp_booking ON vehicle_preparation(booking_id);
CREATE INDEX IF NOT EXISTS idx_vp_status ON vehicle_preparation(overall_status);
COMMENT ON TABLE vehicle_preparation IS 'Pre-dispatch checklist kendaraan — cuci, inspeksi, pengisian BBM, NFC assignment, dan verifikasi dokumen';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 5: VEHICLE TRANSFER (ANTAR POOL)
-- Untuk operasi multi-pool: meminjam/memindah kendaraan antar lokasi
-- Mendukung tipe: PERMANENT, TEMPORARY, LOAN (antar BU/pool)
-- ═══════════════════════════════════════════════════════════════

-- Header request transfer kendaraan antar pool
CREATE TABLE IF NOT EXISTS vehicle_transfer (
    id                      UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_code           VARCHAR(20)     UNIQUE NOT NULL,    -- e.g. TRF-20260509-0001
    transfer_type           VARCHAR(20)     NOT NULL            -- PERMANENT / TEMPORARY / LOAN
                            CHECK (transfer_type IN ('PERMANENT','TEMPORARY','LOAN')),

    -- Pool yang meminjam vs yang menyediakan
    requester_pool_id       UUID            NOT NULL,           -- pool yang request
    requester_pool_name     VARCHAR(150)    NOT NULL,           -- [denorm]
    provider_pool_id        UUID            NOT NULL,           -- pool yang menyediakan
    provider_pool_name      VARCHAR(150)    NOT NULL,           -- [denorm]

    -- Referensi booking (jika transfer karena kebutuhan booking)
    booking_order_id        UUID,
    booking_code            VARCHAR(20),

    total_vehicle           INT             NOT NULL DEFAULT 1,  -- jumlah kendaraan yang ditransfer
    request_status          transfer_status_enum NOT NULL DEFAULT 'DRAFT',

    -- Tanggal
    requested_date          DATE            NOT NULL,
    transfer_start_date     DATE,                               -- tanggal mulai transfer
    transfer_end_date       DATE,                               -- tanggal berakhir (jika TEMPORARY/LOAN)
    actual_transfer_date    DATE,                               -- tanggal aktual transfer

    notes                   TEXT,
    transaction_id          VARCHAR(100)    NOT NULL,           -- saga/event correlation ID

    -- Audit
    status                  SMALLINT        NOT NULL DEFAULT 1, -- soft-delete: 1=active, 0=deleted
    created_by              UUID            NOT NULL,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by             UUID,
    modified_at             TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_vt_status ON vehicle_transfer(request_status);
CREATE INDEX IF NOT EXISTS idx_vt_requester ON vehicle_transfer(requester_pool_id);
CREATE INDEX IF NOT EXISTS idx_vt_provider ON vehicle_transfer(provider_pool_id);
COMMENT ON TABLE vehicle_transfer IS 'Request pemindahan/peminjaman kendaraan antar pool — dengan multi-level approval workflow';

-- Detail per kendaraan dalam satu transfer request
CREATE TABLE IF NOT EXISTS vehicle_transfer_detail (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_transfer_id UUID            NOT NULL REFERENCES vehicle_transfer(id) ON DELETE CASCADE,
    vehicle_id          UUID            REFERENCES master_vehicle(id),   -- null = belum assign unit spesifik
    license_plate       VARCHAR(15),                                      -- [denorm]
    vehicle_type        VARCHAR(20)     NOT NULL,
    vehicle_category    VARCHAR(30),
    brand               VARCHAR(50),
    model               VARCHAR(50),
    year                INT,
    transmission        VARCHAR(20),
    is_revoked          BOOLEAN         NOT NULL DEFAULT FALSE,           -- unit dibatalkan dari transfer ini
    notes               TEXT,
    transaction_id      VARCHAR(100),
    status              SMALLINT        NOT NULL DEFAULT 1,
    created_by          UUID            NOT NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_vtd_transfer ON vehicle_transfer_detail(vehicle_transfer_id);
COMMENT ON TABLE vehicle_transfer_detail IS 'Detail per unit kendaraan dalam satu transfer request';

-- Approval workflow untuk transfer kendaraan — multi-level
CREATE TABLE IF NOT EXISTS vehicle_transfer_approval (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_transfer_id UUID            NOT NULL REFERENCES vehicle_transfer(id) ON DELETE CASCADE,
    approval_level      INT             NOT NULL,                -- 1=pool manager, 2=area manager
    role_name           VARCHAR(100)    NOT NULL,                -- [denorm]
    approver_id         UUID,
    approver_name       VARCHAR(150),                            -- [denorm]
    approval_status     VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                        CHECK (approval_status IN ('PENDING','APPROVED','REJECTED')),
    is_current_approval BOOLEAN         NOT NULL DEFAULT FALSE,  -- apakah ini giliran approval aktif
    approval_date       TIMESTAMPTZ,
    rejection_reason    TEXT,
    transaction_id      VARCHAR(100),
    status              SMALLINT        NOT NULL DEFAULT 1,
    created_by          UUID            NOT NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_vta_transfer ON vehicle_transfer_approval(vehicle_transfer_id);
COMMENT ON TABLE vehicle_transfer_approval IS 'Multi-level approval workflow untuk transfer kendaraan antar pool';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 6: VEHICLE POOL ALLOCATION
-- Manajemen kuota kendaraan per pool dalam periode tertentu.
-- Berguna untuk operasi Haji/Umrah: berapa unit dialokasikan ke pool A vs B.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_pool_allocation (
    id                      UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    period_start            DATE            NOT NULL,
    period_end              DATE            NOT NULL,

    allocation_type         VARCHAR(20)     NOT NULL DEFAULT 'FIXED'
                            CHECK (allocation_type IN ('FIXED','DAILY','EVENT')),

    -- Pool asal & tujuan alokasi
    source_pool_id          UUID            NOT NULL,
    source_pool_name        VARCHAR(150)    NOT NULL,
    target_pool_id          UUID            NOT NULL,
    target_pool_name        VARCHAR(150)    NOT NULL,

    vehicle_type            VARCHAR(20),                         -- null = semua tipe
    vehicle_category        VARCHAR(30),                         -- filter kategori opsional

    total_unit              INT             NOT NULL,            -- kuota unit yang dialokasikan
    daily_out               INT,                                 -- estimasi unit keluar per hari
    daily_in                INT,                                 -- estimasi unit masuk per hari

    is_same_location        BOOLEAN         NOT NULL DEFAULT FALSE,
    vehicle_stock_flag      BOOLEAN,                             -- apakah pool ini menjadi sumber stok
    is_approved             BOOLEAN         NOT NULL DEFAULT FALSE,
    allocation_status       VARCHAR(20)     NOT NULL DEFAULT 'DRAFT'
                            CHECK (allocation_status IN ('DRAFT','PENDING','APPROVED','ACTIVE','EXPIRED','CANCELLED')),

    notes                   TEXT,
    transaction_id          VARCHAR(100),

    -- Audit + soft-delete
    status                  SMALLINT        NOT NULL DEFAULT 1,
    created_by              UUID            NOT NULL,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by             UUID,
    modified_at             TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_vpa_period ON vehicle_pool_allocation(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_vpa_source ON vehicle_pool_allocation(source_pool_id);
CREATE INDEX IF NOT EXISTS idx_vpa_target ON vehicle_pool_allocation(target_pool_id);
CREATE INDEX IF NOT EXISTS idx_vpa_status ON vehicle_pool_allocation(allocation_status);
COMMENT ON TABLE vehicle_pool_allocation IS 'Manajemen kuota unit kendaraan per pool dalam periode tertentu — berguna untuk event Haji/Umrah';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 7: POOL IN/OUT DASHBOARD
-- Agregasi snapshot harian untuk dashboard operasional
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS pool_in_out_dashboard (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    pool_location_id    UUID        NOT NULL,
    pool_location_name  VARCHAR(150) NOT NULL,
    snapshot_date       DATE        NOT NULL,   -- tanggal snapshot
    vehicle_type        VARCHAR(20),            -- null = semua tipe

    -- Aggregasi pool in/out
    total_pool_in       INT         NOT NULL DEFAULT 0,  -- kendaraan masuk pool hari ini
    total_pool_out      INT         NOT NULL DEFAULT 0,  -- kendaraan keluar pool hari ini
    total_dispatch      INT         NOT NULL DEFAULT 0,  -- total dispatch hari ini
    total_return        INT         NOT NULL DEFAULT 0,  -- total return hari ini
    total_transfer_in   INT         NOT NULL DEFAULT 0,  -- transfer masuk dari pool lain
    total_transfer_out  INT         NOT NULL DEFAULT 0,  -- transfer keluar ke pool lain

    -- Snapshot stok
    available_count     INT         NOT NULL DEFAULT 0,
    reserved_count      INT         NOT NULL DEFAULT 0,
    in_use_count        INT         NOT NULL DEFAULT 0,
    maintenance_count   INT         NOT NULL DEFAULT 0,
    total_count         INT         NOT NULL DEFAULT 0,

    -- Kapasitas pool
    pool_capacity       INT,                    -- dari rpk_master.pool_location.capacity
    utilization_pct     DECIMAL(5,2),           -- persentase utilisasi

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(pool_location_id, snapshot_date, vehicle_type)
);

CREATE INDEX IF NOT EXISTS idx_piod_pool ON pool_in_out_dashboard(pool_location_id);
CREATE INDEX IF NOT EXISTS idx_piod_date ON pool_in_out_dashboard(snapshot_date DESC);
COMMENT ON TABLE pool_in_out_dashboard IS 'Snapshot agregasi harian stok & pergerakan kendaraan per pool — untuk dashboard operasional';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 8: VEHICLE STANDBY
-- Kendaraan yang di-pre-assign untuk booking yang akan datang.
-- Berguna untuk operasi Haji: unit "dipegang" sebelum booking confirmed.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_standby (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    pool_location_id    UUID        NOT NULL,
    pool_location_name  VARCHAR(150) NOT NULL,
    vehicle_type        VARCHAR(20) NOT NULL,
    vehicle_category    VARCHAR(30),
    quantity            INT         NOT NULL DEFAULT 1, -- jumlah unit standby
    standby_date        DATE        NOT NULL,
    reason              VARCHAR(200),   -- e.g. "Persiapan jamaah keberangkatan Kloter 5"
    is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
    created_by          UUID        NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ
);

-- Mapping unit spesifik ke standby order
CREATE TABLE IF NOT EXISTS vehicle_standby_mapping (
    id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_standby_id  UUID        NOT NULL REFERENCES vehicle_standby(id) ON DELETE CASCADE,
    vehicle_id          UUID        NOT NULL REFERENCES master_vehicle(id),
    license_plate       VARCHAR(15) NOT NULL,   -- [denorm]
    vehicle_type        VARCHAR(20) NOT NULL,   -- [denorm] snapshot tipe kendaraan
    brand               VARCHAR(50),            -- [denorm] snapshot merek
    model               VARCHAR(50),            -- [denorm] snapshot model
    assigned_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by         UUID        NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_vsm_standby ON vehicle_standby_mapping(vehicle_standby_id);
CREATE INDEX IF NOT EXISTS idx_vsm_vehicle ON vehicle_standby_mapping(vehicle_id);
COMMENT ON TABLE vehicle_standby IS 'Pre-assignment kendaraan untuk kebutuhan operasional yang akan datang (Haji, event khusus, dll)';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 9: VEHICLE_SOFT_BOOKING — REPLICATED
-- Replikasi dari rpk_bookingorder via event SoftBookingCreated / SoftBookingReleased.
-- Inventory Service membaca tabel ini untuk hitung available stock:
--   available = COUNT(AVAILABLE) - COUNT(soft_booking WHERE ACTIVE AND overlap window)
-- INSERT menggunakan ON CONFLICT DO NOTHING → idempotent terhadap duplicate events.
-- Scheduler bersihkan record EXPIRED setiap 5 menit.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_soft_booking (
    -- ID sama dengan rpk_bookingorder.vehicle_soft_booking (sync via event)
    id                  UUID        PRIMARY KEY,

    booking_code        VARCHAR(20) NOT NULL,       -- reference key dari BookingOrder Service
    booking_detail_id   UUID        NOT NULL,        -- reference key dari BookingOrderDetail

    -- Filter stok oleh Inventory Service
    vehicle_type        VARCHAR(20) NOT NULL,
    pool_location_id    UUID        NOT NULL,    -- reference ke rpk_master.pool_location (cross-service, no FK)
    pool_location_name  VARCHAR(150) NOT NULL,   -- [denorm] snapshot nama pool — tanpa join ke master

    -- Window untuk cek overlap saat reserve stok
    start_rental_at     TIMESTAMPTZ NOT NULL,
    end_rental_at       TIMESTAMPTZ NOT NULL,
    expires_at          TIMESTAMPTZ NOT NULL,        -- Inventory scheduler hapus yang EXPIRED

    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','EXPIRED','CONVERTED','RELEASED')),

    -- Jumlah unit yang di-hold
    number_of_vehicles  INT         NOT NULL DEFAULT 1,

    -- Metadata replikasi
    synced_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- kapan di-sync dari event
    sequence            INT         NOT NULL DEFAULT 1,     -- direplikasi dari source
    transaction_id      VARCHAR(100) NOT NULL               -- CorrelationId dari source event
);

CREATE INDEX IF NOT EXISTS idx_vsb_pool_type  ON vehicle_soft_booking(pool_location_id, vehicle_type);
CREATE INDEX IF NOT EXISTS idx_vsb_window_rep ON vehicle_soft_booking(start_rental_at, end_rental_at);
CREATE INDEX IF NOT EXISTS idx_vsb_status_rep ON vehicle_soft_booking(status);
CREATE INDEX IF NOT EXISTS idx_vsb_expires_rep ON vehicle_soft_booking(expires_at)
    WHERE status = 'ACTIVE';   -- partial index — hanya ACTIVE yang dipantau scheduler

COMMENT ON TABLE vehicle_soft_booking IS
  'Replikasi dari rpk_bookingorder via SoftBookingCreated event. '
  'Dipakai Inventory Service untuk hitung effective available stock. '
  'INSERT idempotent dengan ON CONFLICT DO NOTHING.';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 10: VEHICLE_ASSIGNMENT — REPLICATED
-- Replikasi dari rpk_bookingorder via event VehicleAssigned / AssignmentCancelled.
-- Inventory Service gunakan tabel ini untuk:
--   1. UPDATE master_vehicle SET status = READY WHERE id = vehicle_id
--   2. Mapping NFC card ke vehicle (nfc_card_uid)
--   3. Dashboard: tampilkan unit mana yang sedang di-dispatch
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS vehicle_assignment (
    -- ID sama dengan rpk_bookingorder.vehicle_assignment (sync via event)
    id                  UUID        PRIMARY KEY,

    booking_code        VARCHAR(20) NOT NULL,           -- reference key dari BookingOrder

    -- FK ke MasterVehicle (same DB — inilah satu-satunya FK di sini)
    vehicle_id          UUID        NOT NULL REFERENCES master_vehicle(id),

    license_plate       VARCHAR(15) NOT NULL,            -- denorm untuk query cepat tanpa join
    vehicle_type        VARCHAR(20) NOT NULL,            -- snapshot
    vehicle_category    VARCHAR(30),                     -- snapshot (SUV, MPV, Matic, dll)
    brand               VARCHAR(50),                     -- snapshot
    model               VARCHAR(50),                     -- snapshot

    -- Driver (reference only — no FK ke rpk_driver)
    driver_id           UUID,
    driver_name         VARCHAR(150),                    -- snapshot untuk tampilan dashboard

    -- NFC card yang mapped ke vehicle ini saat dispatch
    nfc_card_uid        VARCHAR(50),

    -- Pool dispatch
    pool_location_id    UUID        NOT NULL,            -- FK ke pool (ref only, no FK constraint)
    pool_location_name  VARCHAR(150) NOT NULL,

    assigned_at         TIMESTAMPTZ NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING','DISPATCHED','ACTIVE','RETURNED','CANCELLED')),

    -- status assignment numerik: 0=ASSIGNED, 1=RELEASED, 2=REJECTED
    assignment_status   SMALLINT    NOT NULL DEFAULT 0,

    -- Metadata replikasi
    synced_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sequence            INT         NOT NULL DEFAULT 1,  -- direplikasi dari source
    transaction_id      VARCHAR(100) NOT NULL            -- CorrelationId dari source event
);

CREATE INDEX IF NOT EXISTS idx_va_vehicle_rep ON vehicle_assignment(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_va_nfc_rep     ON vehicle_assignment(nfc_card_uid)
    WHERE nfc_card_uid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_va_status_rep  ON vehicle_assignment(status);
CREATE INDEX IF NOT EXISTS idx_va_pool_rep    ON vehicle_assignment(pool_location_id);

COMMENT ON TABLE vehicle_assignment IS
  'Replikasi dari rpk_bookingorder via VehicleAssigned event. '
  'Inventory Service consume event ini → UPDATE master_vehicle status=READY '
  'dan mapping NFC card ke vehicle. INSERT idempotent dengan ON CONFLICT DO NOTHING.';

-- ═══════════════════════════════════════════════════════════════
-- BAGIAN 11: OUTBOX (existing pattern dipertahankan)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS outbox_message (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    exchange        VARCHAR(100)    NOT NULL,
    routing_key     VARCHAR(100)    NOT NULL,
    event_type      VARCHAR(100)    NOT NULL,
    payload         JSONB           NOT NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','PROCESSING','PUBLISHED','FAILED')),
    retry_count     INT             NOT NULL DEFAULT 0,
    error_message   TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    processed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_outbox_status ON outbox_message(status, created_at);
CREATE INDEX IF NOT EXISTS idx_outbox_exchange ON outbox_message(exchange);

-- ─────────────────────────────────────────────────────────────
-- SEED DATA — Lookup tables
-- ─────────────────────────────────────────────────────────────
INSERT INTO vehicle_category (id, code, name, vehicle_type, created_by) VALUES
  (uuid_generate_v4(), 'MPV',       'MPV (Multi Purpose Vehicle)',  'CAR',         '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'SUV',       'SUV (Sport Utility Vehicle)',  'CAR',         '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'CITY_CAR',  'City Car',                     'CAR',         '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'SPORT',     'Sport Car',                    'CAR',         '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'PICKUP',    'Pickup Truck',                 'CAR',         '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'MINIVAN',   'Minivan / Microbus',           'CAR',         '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'MATIC',     'Skuter Matic',                 'MOTORCYCLE',  '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'BEBEK',     'Motor Bebek',                  'MOTORCYCLE',  '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'SPORT_MTC', 'Motor Sport',                  'MOTORCYCLE',  '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO vehicle_transmission_type (id, code, name, created_by) VALUES
  (uuid_generate_v4(), 'MANUAL',    'Manual',               '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'AUTOMATIC', 'Automatic (AT)',        '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'CVT',       'CVT (Belt Drive)',      '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'DCT',       'DCT (Dual Clutch)',     '00000000-0000-0000-0000-000000000001'),
  (uuid_generate_v4(), 'AMT',       'AMT (Automated Manual)','00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

