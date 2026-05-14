-- ═══════════════════════════════════════════════════════════════════════════
--  RENT PAK HAJI — rpk_payment Schema
--  Owner   : Payment Service (.NET)
--  Author  : Rizkalfin Bagas Aminullah
--  Version : 1.0.0  |  May 2026
--
--  Tabel dalam DB ini:
--    1. invoice         → Tagihan yang digenerate saat order CONFIRMED
--    2. payment         → Satu percobaan pembayaran (satu invoice bisa punya beberapa attempt)
--    3. refund          → Request dan proses refund ke customer
--    4. outbox_message  → Reliable event delivery (Outbox pattern)
--
--  Improvement atas design dasar:
--    ✓ Multi payment attempt  → invoice bisa punya >1 payment (gagal → coba lagi)
--    ✓ Payment gateway-ready  → gateway_provider, gateway_ref, va_number, qr_code_url
--    ✓ Virtual Account support→ va_number, va_bank, va_expiry
--    ✓ QRIS support           → qr_code_url, qr_expiry
--    ✓ Refund tracking        → partial / full refund per item
--    ✓ transactionId          → Saga correlation lintas service
--    ✓ Idempotency key        → Cegah double-charge dari client retry
-- ═══════════════════════════════════════════════════════════════════════════

\c rpk_payment;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────
-- ENUM TYPES
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE invoice_status AS ENUM (
    'DRAFT',        -- dibuat tapi belum dikirim ke customer
    'ISSUED',       -- sudah dikirim / aktif menunggu pembayaran
    'PAID',         -- sudah lunas
    'PARTIALLY_PAID', -- bayar sebagian (untuk kasus DP)
    'OVERDUE',      -- melewati due date belum dibayar
    'CANCELLED',    -- dibatalkan (order cancel)
    'REFUNDED'      -- sudah di-refund penuh
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM (
    'PENDING',      -- menunggu konfirmasi dari gateway
    'SUCCESS',      -- pembayaran berhasil dikonfirmasi gateway
    'FAILED',       -- gagal (expired, insufficient fund, dll)
    'EXPIRED',      -- VA/QR expired tanpa pembayaran
    'CANCELLED'     -- dibatalkan oleh sistem / customer
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_method AS ENUM (
    'VIRTUAL_ACCOUNT',  -- transfer ke nomor VA
    'QRIS',             -- scan QR code (GoPay, OVO, Dana, LinkAja, dll)
    'CREDIT_CARD',      -- kartu kredit
    'BANK_TRANSFER',    -- transfer manual (konfirmasi manual)
    'CASH',             -- bayar tunai ke operator
    'VOUCHER_FULL'      -- 100% dibayar via voucher/diskon
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE refund_status AS ENUM (
    'REQUESTED',    -- customer / operator request refund
    'UNDER_REVIEW', -- sedang direview finance
    'APPROVED',     -- disetujui, menunggu proses ke gateway
    'PROCESSING',   -- sedang diproses gateway
    'COMPLETED',    -- dana sudah kembali ke customer
    'REJECTED'      -- ditolak dengan alasan
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════════
-- TABEL 1: INVOICE
-- Tagihan resmi yang digenerate oleh Payment Service.
-- Satu booking_order → satu invoice.
-- Invoice dibuat saat order berstatus CONFIRMED.
-- Customer melakukan pembayaran terhadap invoice ini.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS invoice (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Nomor invoice yang tampil ke customer
    invoice_number      VARCHAR(30)     UNIQUE NOT NULL,
    -- Format: INV-YYYYMMDD-XXXX  e.g. INV-20260509-0001

    -- Referensi ke BookingOrder Service (cross-service, no FK)
    booking_order_id    UUID            NOT NULL,
    booking_code        VARCHAR(20)     NOT NULL,   -- [denorm]

    -- Snapshot customer (dari event BookingOrderConfirmed)
    customer_id         UUID            NOT NULL,
    customer_name       VARCHAR(150)    NOT NULL,   -- snapshot
    customer_phone      VARCHAR(20)     NOT NULL,   -- snapshot
    customer_email      VARCHAR(150),               -- snapshot

    -- Status invoice
    status              invoice_status  NOT NULL DEFAULT 'DRAFT',

    -- Breakdown pembayaran (snapshot dari booking_order)
    subtotal_amount     DECIMAL(18,2)   NOT NULL,   -- sebelum diskon
    discount_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,  -- total diskon (voucher + special)
    tax_amount          DECIMAL(18,2)   NOT NULL DEFAULT 0,  -- PPN jika applicable
    total_amount        DECIMAL(18,2)   NOT NULL,   -- yang harus dibayar customer
    paid_amount         DECIMAL(18,2)   NOT NULL DEFAULT 0,  -- total yang sudah dibayar

    -- Voucher info (jika ada)
    voucher_code        VARCHAR(50),
    voucher_discount    DECIMAL(18,2)   NOT NULL DEFAULT 0,

    -- Line items dalam JSONB (snapshot detail booking)
    -- Structure: [{ line_number, vehicle_type, vehicle_category, duration_days, daily_rate, subtotal, with_driver }]
    line_items          JSONB           NOT NULL DEFAULT '[]',

    -- Tanggal
    issued_at           TIMESTAMPTZ,                -- kapan invoice diterbitkan ke customer
    due_at              TIMESTAMPTZ,                -- batas waktu pembayaran
    paid_at             TIMESTAMPTZ,                -- kapan lunas

    -- Notes
    notes               TEXT,

    -- Saga correlation
    transaction_id      VARCHAR(100)    NOT NULL,   -- saga/event correlation ID

    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inv_booking   ON invoice(booking_order_id);
CREATE INDEX IF NOT EXISTS idx_inv_customer  ON invoice(customer_id);
CREATE INDEX IF NOT EXISTS idx_inv_status    ON invoice(status);
CREATE INDEX IF NOT EXISTS idx_inv_due       ON invoice(due_at) WHERE status IN ('ISSUED','PARTIALLY_PAID');
CREATE INDEX IF NOT EXISTS idx_inv_number    ON invoice(invoice_number);

COMMENT ON TABLE invoice IS
  'Tagihan resmi ke customer — snapshot booking + breakdown harga. '
  'Satu booking_order → satu invoice. Multi payment attempt per invoice diperbolehkan.';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 2: PAYMENT
-- Satu percobaan pembayaran terhadap sebuah invoice.
-- Satu invoice bisa punya >1 payment record (attempt gagal → coba lagi dengan metode lain).
-- Hanya 1 payment yang boleh berstatus SUCCESS per invoice.
--
-- Improvement:
--   • Virtual Account → va_number, va_bank, va_expiry
--   • QRIS → qr_code_url, qr_expiry
--   • Gateway agnostic → gateway_provider, gateway_ref
--   • Idempotency key → cegah double-charge jika client retry
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS payment (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    invoice_id          UUID            NOT NULL,   -- ref ke invoice (same DB)
    booking_code        VARCHAR(20)     NOT NULL,   -- [denorm] untuk tracing cepat

    -- Metode & status pembayaran
    payment_method      payment_method  NOT NULL,
    status              payment_status  NOT NULL DEFAULT 'PENDING',

    -- Jumlah yang dibayar pada percobaan ini
    amount              DECIMAL(18,2)   NOT NULL,

    -- Payment Gateway Integration
    -- Midtrans, Xendit, atau gateway lain yang dipakai
    gateway_provider    VARCHAR(30),
    -- e.g. MIDTRANS, XENDIT, MANUAL
    gateway_ref         VARCHAR(100),   -- ID transaksi dari gateway (untuk reconcile)
    gateway_response    JSONB,          -- raw response dari gateway (untuk debugging)

    -- Virtual Account (jika payment_method = VIRTUAL_ACCOUNT)
    va_number           VARCHAR(30),    -- nomor virtual account
    va_bank             VARCHAR(20),    -- bank penyelenggara VA (BCA, BNI, BRI, Mandiri, dll)
    va_expiry           TIMESTAMPTZ,    -- kapan VA expired

    -- QRIS (jika payment_method = QRIS)
    qr_code_url         VARCHAR(500),   -- URL gambar QR code
    qr_string           TEXT,           -- raw QRIS string (untuk generate QR di client)
    qr_expiry           TIMESTAMPTZ,    -- kapan QR expired

    -- Idempotency — cegah double charge jika client retry
    idempotency_key     VARCHAR(100)    UNIQUE NOT NULL,

    -- Timestamps
    paid_at             TIMESTAMPTZ,    -- kapan payment SUCCESS (dari webhook gateway)
    expired_at          TIMESTAMPTZ,    -- kapan payment EXPIRED

    -- Catatan
    failure_reason      VARCHAR(200),   -- alasan gagal/expired (dari gateway)
    notes               TEXT,

    -- Saga correlation
    transaction_id      VARCHAR(100)    NOT NULL,   -- saga/event correlation ID

    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pay_invoice   ON payment(invoice_id);
CREATE INDEX IF NOT EXISTS idx_pay_status    ON payment(status);
CREATE INDEX IF NOT EXISTS idx_pay_gateway   ON payment(gateway_ref) WHERE gateway_ref IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pay_va        ON payment(va_number) WHERE va_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pay_pending   ON payment(va_expiry)
    WHERE status = 'PENDING' AND payment_method = 'VIRTUAL_ACCOUNT';

COMMENT ON TABLE payment IS
  'Satu percobaan pembayaran per invoice. Satu invoice bisa multi-attempt. '
  'Gateway-agnostic: support VA, QRIS, Credit Card, Cash. '
  'Idempotency key mencegah double-charge pada client retry.';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 3: REFUND
-- Request dan tracking proses pengembalian dana ke customer.
-- Dibuat saat booking dibatalkan setelah pembayaran PAID.
-- Support partial refund (misal: batal sebagian hari).
--
-- Improvement:
--   • Partial refund → refund_amount bisa < paid_amount
--   • Multi-step approval → status workflow lengkap
--   • Gateway refund tracking → gateway_ref_refund
--   • Alasan refund terstruktur → refund_reason_type
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS refund (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    invoice_id          UUID            NOT NULL,           -- ref ke invoice (same DB)
    payment_id          UUID            NOT NULL,           -- payment yang di-refund
    booking_code        VARCHAR(20)     NOT NULL,           -- [denorm]

    -- Customer snapshot
    customer_id         UUID            NOT NULL,
    customer_name       VARCHAR(150)    NOT NULL,           -- snapshot

    -- Jumlah refund
    original_amount     DECIMAL(18,2)   NOT NULL,           -- total yang pernah dibayar
    refund_amount       DECIMAL(18,2)   NOT NULL,           -- jumlah yang dikembalikan (support partial)
    -- jika refund_amount < original_amount → partial refund (ada penalty cancellation)
    penalty_amount      DECIMAL(18,2)   NOT NULL DEFAULT 0, -- biaya penalty/admin

    -- Alasan refund
    refund_reason_type  SMALLINT        NOT NULL,
    -- 0=Customer Cancel, 1=Operator Cancel, 2=Vehicle Unavailable,
    -- 3=Payment Error, 4=Force Majeure, 5=Other
    refund_reason_note  TEXT,

    -- Status refund
    status              refund_status   NOT NULL DEFAULT 'REQUESTED',

    -- Metode pengembalian dana
    refund_method       VARCHAR(30)     NOT NULL DEFAULT 'GATEWAY_REVERSAL',
    -- GATEWAY_REVERSAL (auto via gateway), BANK_TRANSFER (manual), CASH (tunai)

    -- Rekening tujuan refund (jika BANK_TRANSFER)
    bank_name           VARCHAR(50),
    bank_account_number VARCHAR(30),
    bank_account_name   VARCHAR(150),

    -- Gateway refund tracking
    gateway_ref_refund  VARCHAR(100),   -- ID refund dari gateway

    -- Review & approval
    reviewed_by         UUID,
    reviewed_by_name    VARCHAR(150),   -- [denorm]
    reviewed_at         TIMESTAMPTZ,
    rejection_reason    TEXT,

    -- Proses
    processed_at        TIMESTAMPTZ,    -- kapan mulai diproses ke gateway
    completed_at        TIMESTAMPTZ,    -- kapan dana sudah kembali ke customer

    -- Saga correlation
    transaction_id      VARCHAR(100)    NOT NULL,

    -- Audit
    created_by          UUID,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ref_invoice   ON refund(invoice_id);
CREATE INDEX IF NOT EXISTS idx_ref_payment   ON refund(payment_id);
CREATE INDEX IF NOT EXISTS idx_ref_customer  ON refund(customer_id);
CREATE INDEX IF NOT EXISTS idx_ref_status    ON refund(status);

COMMENT ON TABLE refund IS
  'Pengembalian dana ke customer — support partial refund dan penalty cancellation. '
  'Multi-step: REQUESTED → UNDER_REVIEW → APPROVED → PROCESSING → COMPLETED/REJECTED. '
  'Gateway-agnostic: auto reversal, bank transfer manual, atau cash.';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 4: OUTBOX_MESSAGE
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
