-- ═══════════════════════════════════════════════════════════════════════════
--  RENT PAK HAJI — rpk_notification Schema
--  Owner   : Notification Service (NestJS)
--  Author  : Rizkalfin Bagas Aminullah
--  Version : 1.0.0  |  May 2026
--
--  Tabel dalam DB ini:
--    1. notification_template → Template pesan per event & channel
--    2. notification_log      → Log setiap notifikasi yang dikirim / dicoba
--    3. device_token          → FCM/APNs token untuk push notification
--
--  Improvement atas design dasar:
--    ✓ Multi-channel         → WhatsApp, Email, Push (FCM), SMS
--    ✓ Template engine       → Mustache-style placeholder {{booking_code}}
--    ✓ Per-channel template  → Satu event punya template berbeda per channel
--    ✓ Read receipt          → read_at timestamp untuk tracking
--    ✓ Retry built-in        → retry_count, max_retry, next_retry_at
--    ✓ Device token mgmt     → Multi device per customer (tablet + HP)
--    ✓ Priority & scheduling → priority level + scheduled_at untuk blast
-- ═══════════════════════════════════════════════════════════════════════════

\c rpk_notification;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────────────────────────
-- ENUM TYPES
-- ─────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE notification_channel AS ENUM (
    'WHATSAPP',     -- via WA Business API (Fonnte, Wablas, atau Meta Cloud API)
    'EMAIL',        -- via SMTP / Mailgun / SendGrid
    'PUSH',         -- Firebase Cloud Messaging (FCM) / APNs
    'SMS'           -- via SMS gateway (sebagai fallback)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE notification_status AS ENUM (
    'PENDING',      -- antri, belum dikirim
    'SENDING',      -- sedang dalam proses kirim
    'SENT',         -- berhasil dikirim ke provider (belum tentu dibaca)
    'DELIVERED',    -- provider konfirmasi delivered ke device
    'READ',         -- customer sudah membaca (jika provider support read receipt)
    'FAILED',       -- gagal kirim (akan di-retry jika retry_count < max_retry)
    'CANCELLED'     -- dibatalkan sebelum dikirim (misal order cancel sebelum notif terkirim)
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ═══════════════════════════════════════════════════════════════
-- TABEL 1: NOTIFICATION_TEMPLATE
-- Template pesan per event_type dan channel.
-- Satu event bisa punya template berbeda untuk WA, Email, Push.
-- Menggunakan Mustache-style placeholder: {{booking_code}}, {{customer_name}}, dll.
--
-- Improvement:
--   • Versi template  → versi + is_active untuk A/B testing / rollback mudah
--   • Bahasa          → lang (id / en) untuk multi-bahasa di masa depan
--   • Subject email   → field terpisah untuk email subject line
--   • Preview URL     → untuk link tracking pada email marketing
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS notification_template (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Identitas template
    event_type          VARCHAR(100)    NOT NULL,
    -- e.g. BOOKING_CONFIRMED, PAYMENT_SUCCESS, DISPATCH_READY,
    --      VEHICLE_DISPATCHED, VEHICLE_RETURNED, PAYMENT_FAILED,
    --      BOOKING_CANCELLED, REFUND_PROCESSED, SIM_EXPIRY_WARNING

    channel             notification_channel NOT NULL,

    -- Versi template (untuk rollback / A/B)
    version             INT             NOT NULL DEFAULT 1,
    lang                VARCHAR(5)      NOT NULL DEFAULT 'id',  -- 'id' atau 'en'

    -- Konten template
    -- WhatsApp/SMS: isi pesan dengan placeholder Mustache {{variable}}
    -- Email: body HTML dengan placeholder
    -- Push: message body (max ~200 char)
    subject             VARCHAR(200),   -- khusus EMAIL: subject line
    body                TEXT            NOT NULL,
    -- Contoh body WA:
    -- "Halo {{customer_name}}, booking Anda *{{booking_code}}* telah dikonfirmasi! 🚗
    --  Detail:\n• Kendaraan: {{vehicle_type}}\n• Mulai: {{start_date}}\n• Pool: {{pool_name}}"

    -- Metadata
    description         TEXT,           -- catatan internal untuk template ini
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_by          UUID            NOT NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    modified_at         TIMESTAMPTZ,

    -- Satu kombinasi event+channel+lang+version harus unik
    UNIQUE(event_type, channel, lang, version)
);

CREATE INDEX IF NOT EXISTS idx_ntmpl_event   ON notification_template(event_type);
CREATE INDEX IF NOT EXISTS idx_ntmpl_channel ON notification_template(channel);
CREATE INDEX IF NOT EXISTS idx_ntmpl_active  ON notification_template(is_active, event_type, channel);

COMMENT ON TABLE notification_template IS
  'Template pesan per event_type + channel + bahasa. '
  'Placeholder: {{customer_name}}, {{booking_code}}, {{vehicle_type}}, {{start_date}}, {{pool_name}}, dll. '
  'Versioning memungkinkan rollback template tanpa downtime.';

-- Seed: Template dasar untuk event-event utama
INSERT INTO notification_template (id, event_type, channel, subject, body, created_by) VALUES

  -- BOOKING_CONFIRMED → WA
  (uuid_generate_v4(), 'BOOKING_CONFIRMED', 'WHATSAPP', NULL,
   'Halo {{customer_name}}! 😊 Booking Anda *{{booking_code}}* telah *DIKONFIRMASI*.'||chr(10)||
   'Detail:'||chr(10)||
   '• Kendaraan : {{vehicle_type}} - {{vehicle_category}}'||chr(10)||
   '• Jumlah    : {{number_of_vehicles}} unit'||chr(10)||
   '• Mulai     : {{start_date}}'||chr(10)||
   '• Selesai   : {{end_date}}'||chr(10)||
   '• Pool      : {{pool_name}}'||chr(10)||chr(10)||
   'Silakan lakukan pembayaran sebelum {{payment_due}}. Terima kasih!',
   '00000000-0000-0000-0000-000000000001'),

  -- PAYMENT_SUCCESS → WA
  (uuid_generate_v4(), 'PAYMENT_SUCCESS', 'WHATSAPP', NULL,
   '✅ Pembayaran *BERHASIL* untuk booking *{{booking_code}}*!'||chr(10)||
   'Nominal   : Rp {{amount}}'||chr(10)||
   'Metode    : {{payment_method}}'||chr(10)||
   'Invoice   : {{invoice_number}}'||chr(10)||chr(10)||
   'Kendaraan Anda akan siap pada {{dispatch_date}}. Kami akan menghubungi Anda sebelum dispatch.',
   '00000000-0000-0000-0000-000000000001'),

  -- VEHICLE_DISPATCHED → WA
  (uuid_generate_v4(), 'VEHICLE_DISPATCHED', 'WHATSAPP', NULL,
   '🚗 Kendaraan Anda sudah *BERANGKAT* dari pool!'||chr(10)||
   'Booking   : *{{booking_code}}*'||chr(10)||
   'Kendaraan : {{brand}} {{model}} ({{license_plate}})'||chr(10)||
   '{% if driver_name %}Sopir     : {{driver_name}} ({{driver_phone}}){% endif %}'||chr(10)||
   'NFC Card  : {{nfc_card_uid}}'||chr(10)||chr(10)||
   'Selamat menikmati perjalanan Anda! 🙏',
   '00000000-0000-0000-0000-000000000001'),

  -- VEHICLE_RETURNED → WA
  (uuid_generate_v4(), 'VEHICLE_RETURNED', 'WHATSAPP', NULL,
   '✅ Kendaraan *{{license_plate}}* telah *DIKEMBALIKAN* ke pool.'||chr(10)||
   'Booking   : *{{booking_code}}*'||chr(10)||
   'Pool      : {{return_pool}}'||chr(10)||
   'Waktu     : {{returned_at}}'||chr(10)||chr(10)||
   'Terima kasih telah menggunakan layanan Rent Pak Haji! 🙏',
   '00000000-0000-0000-0000-000000000001'),

  -- BOOKING_CANCELLED → WA
  (uuid_generate_v4(), 'BOOKING_CANCELLED', 'WHATSAPP', NULL,
   '❌ Booking *{{booking_code}}* telah *DIBATALKAN*.'||chr(10)||
   'Alasan : {{cancellation_reason}}'||chr(10)||
   '{% if refund_amount %}Refund Rp {{refund_amount}} akan diproses dalam {{refund_days}} hari kerja.{% endif %}'||chr(10)||chr(10)||
   'Untuk pertanyaan, hubungi CS kami. Terima kasih.',
   '00000000-0000-0000-0000-000000000001'),

  -- PAYMENT_SUCCESS → EMAIL
  (uuid_generate_v4(), 'PAYMENT_SUCCESS', 'EMAIL',
   '[Rent Pak Haji] Pembayaran Berhasil — {{booking_code}}',
   '<h2>Pembayaran Berhasil</h2><p>Halo {{customer_name}},</p>'||
   '<p>Pembayaran untuk booking <strong>{{booking_code}}</strong> sebesar <strong>Rp {{amount}}</strong> '||
   'telah berhasil diterima.</p>'||
   '<p>Invoice <strong>{{invoice_number}}</strong> dapat diunduh melalui aplikasi.</p>'||
   '<p>Salam,<br/>Tim Rent Pak Haji</p>',
   '00000000-0000-0000-0000-000000000001'),

  -- PAYMENT_FAILED → PUSH
  (uuid_generate_v4(), 'PAYMENT_FAILED', 'PUSH',
   'Pembayaran Gagal',
   'Pembayaran booking {{booking_code}} gagal. Silakan coba lagi sebelum {{payment_due}}.',
   '00000000-0000-0000-0000-000000000001')

ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- TABEL 2: NOTIFICATION_LOG
-- Record setiap notifikasi yang dikirim atau dicoba kirim.
-- Satu event bisa menghasilkan >1 log (WA + Email + Push sekaligus).
--
-- Improvement:
--   • Read receipt tracking → read_at
--   • Retry dengan exponential backoff → retry_count, next_retry_at
--   • Provider response → provider_ref, provider_response JSONB
--   • Scheduled blast → scheduled_at untuk notif yang di-delay
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS notification_log (
    id                      UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Template yang dipakai
    template_id             UUID,       -- ref ke notification_template (nullable: jika template dihapus)
    event_type              VARCHAR(100) NOT NULL,      -- e.g. BOOKING_CONFIRMED
    channel                 notification_channel NOT NULL,

    -- Penerima
    recipient_id            UUID,       -- customer_id / driver_id / operator_id (cross-service ref)
    recipient_type          VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER',
    -- CUSTOMER, DRIVER, OPERATOR, SYSTEM

    recipient_phone         VARCHAR(20),    -- untuk WA / SMS
    recipient_email         VARCHAR(150),   -- untuk EMAIL
    device_token_id         UUID,           -- untuk PUSH (ref ke device_token)

    -- Konten yang dikirim (setelah placeholder di-render)
    subject                 VARCHAR(200),   -- subject email
    body                    TEXT            NOT NULL,   -- pesan yang sudah di-render

    -- Context booking (untuk tracing)
    booking_code            VARCHAR(20),    -- [denorm] booking terkait
    transaction_id          VARCHAR(100),   -- saga/event correlation ID

    -- Status pengiriman
    status                  notification_status NOT NULL DEFAULT 'PENDING',

    -- Retry
    retry_count             INT         NOT NULL DEFAULT 0,
    max_retry               INT         NOT NULL DEFAULT 3,
    next_retry_at           TIMESTAMPTZ,    -- kapan retry berikutnya (exponential backoff)

    -- Provider integration
    provider_ref            VARCHAR(100),   -- ID pesan dari provider (WA, email, FCM)
    provider_response       JSONB,          -- raw response untuk debugging
    failure_reason          TEXT,           -- pesan error dari provider

    -- Timestamps
    scheduled_at            TIMESTAMPTZ,    -- null = kirim segera; ada isi = delay/blast
    sent_at                 TIMESTAMPTZ,    -- kapan dikirim ke provider
    delivered_at            TIMESTAMPTZ,    -- kapan provider konfirmasi delivered
    read_at                 TIMESTAMPTZ,    -- kapan customer baca (WA read receipt / push opened)
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nlog_status    ON notification_log(status, created_at)
    WHERE status IN ('PENDING','FAILED');
CREATE INDEX IF NOT EXISTS idx_nlog_retry     ON notification_log(next_retry_at)
    WHERE status = 'FAILED' AND retry_count < max_retry;
CREATE INDEX IF NOT EXISTS idx_nlog_recipient ON notification_log(recipient_id);
CREATE INDEX IF NOT EXISTS idx_nlog_booking   ON notification_log(booking_code)
    WHERE booking_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_nlog_channel   ON notification_log(channel, status);
CREATE INDEX IF NOT EXISTS idx_nlog_event     ON notification_log(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_nlog_scheduled ON notification_log(scheduled_at)
    WHERE status = 'PENDING' AND scheduled_at IS NOT NULL;

COMMENT ON TABLE notification_log IS
  'Log setiap pengiriman notifikasi — satu event bisa trigger log di beberapa channel sekaligus. '
  'Built-in retry dengan exponential backoff. Read receipt tracking untuk WA & Push.';

-- ═══════════════════════════════════════════════════════════════
-- TABEL 3: DEVICE_TOKEN
-- Menyimpan FCM/APNs token untuk push notification.
-- Satu customer bisa punya beberapa device (HP + tablet).
-- Token diupdate setiap kali aplikasi di-install ulang / login.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS device_token (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Pemilik token
    owner_id        UUID        NOT NULL,       -- customer_id / driver_id (cross-service ref)
    owner_type      VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER',  -- CUSTOMER, DRIVER, OPERATOR

    -- Token device
    token           TEXT        NOT NULL UNIQUE,    -- FCM registration token / APNs device token
    platform        VARCHAR(10) NOT NULL
                    CHECK (platform IN ('ANDROID','IOS','WEB')),

    -- Metadata device
    device_name     VARCHAR(100),   -- "Kalfin's iPhone 15" (dari user agent / app)
    app_version     VARCHAR(20),    -- versi app saat token didaftarkan

    -- Status
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,

    -- Timestamps
    last_used_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),     -- kapan terakhir berhasil terkirim
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dtok_owner    ON device_token(owner_id, owner_type);
CREATE INDEX IF NOT EXISTS idx_dtok_active   ON device_token(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_dtok_platform ON device_token(platform);

COMMENT ON TABLE device_token IS
  'FCM/APNs token untuk push notification. '
  'Satu customer bisa multi device. Token di-invalidate otomatis jika push FAILED (token expired).';
