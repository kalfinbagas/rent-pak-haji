# 🗺️ RENT PAK HAJI — Project Roadmap & Checklist

> **Author:** Rizkalfin Bagas Aminullah  
> **Stack:** .NET 10 · NestJS · PostgreSQL · RabbitMQ · Redis · Docker  
> **Updated:** May 2026

---

## Legenda
- `[x]` → Selesai
- `[ ]` → Belum dikerjakan
- `[~]` → Sebagian selesai / in progress

---

## PHASE 0 — Prerequisites (Instalasi Tools)
> Semua sudah terinstall. Verifikasi dengan command di bawah.

```bash
docker --version          # Docker Engine 27.x+
docker compose version    # Docker Compose v2.x+
dotnet --version          # .NET 10.x.x
dotnet ef --version       # EF Core tools 10.x.x
node --version            # Node.js 20.x+
npm --version             # npm 10.x+
nest --version            # NestJS CLI 10.x+
git --version             # Git 2.x+
```

- [x] WSL2 enabled
- [x] Docker Desktop installed & running
- [x] .NET 10 SDK installed
- [x] `dotnet-ef` tool installed globally
- [x] Node.js LTS installed
- [x] NestJS CLI installed (`npm install -g @nestjs/cli`)
- [x] Git installed & configured
- [x] Visual Studio 2022 / VS Code installed
- [x] DBeaver / pgAdmin installed
- [x] Postman installed

---

## PHASE 1 — Docker Infrastructure ✅

- [x] `docker-compose.yml` dibuat & dikonfigurasi
- [x] Semua container running & healthy
- [x] PostgreSQL healthy (port 5432)
- [x] RabbitMQ healthy (AMQP: 5672, UI: 15672)
- [x] Redis healthy (port 6379)
- [x] Seq running (port 8081)
- [x] Jaeger running (port 16686)
- [x] pgAdmin running (port 8080)
- [x] Mosquitto MQTT running (port 1883 / 9001)

### 🌐 Service URLs

| Service | URL | Credentials |
|---|---|---|
| pgAdmin | http://localhost:8080 | kalfinbagas@gmail.com / admin123 |
| RabbitMQ UI | http://localhost:15672 | rpk_admin / RpkSecure2026! |
| Seq (Logs) | http://localhost:8081 | — |
| Jaeger (Tracing) | http://localhost:16686 | — |

---

## PHASE 2 — Database Setup ✅

- [x] `infrastructure/scripts/init-db.sql` — 9 database
- [x] `rpk_master_schema.sql` — pool_location, customer, vehicle_driver_pair, approval_matrix, nfc_card, voucher
- [x] `rpk_vehicle_schema.sql` — 15 tabel (master_vehicle, movement, preparation, transfer, allocation, standby, soft_booking, assignment, dll)
- [x] `rpk_bookingorder_schema.sql` — 5 tabel (booking_order + payment_expires_at, detail, soft_booking, assignment)
- [x] `rpk_journey_schema.sql` — journey, journey_pool_event
- [x] `rpk_driver_schema.sql` — driver, driver_availability
- [x] `rpk_payment_schema.sql` — invoice, payment (VA + QRIS), refund
- [x] `rpk_notification_schema.sql` — 3 tabel + 7 seed template (WA, Email, Push)
- [x] Semua 9 database verified di PostgreSQL
- [x] Semua tabel verified per database
- [x] Seed data notification_template verified

---

## PHASE 3 — Repository & Project Structure

- [ ] Buat GitHub repository `rent-pak-haji` (main)
- [ ] Buat GitHub repository `rent-pak-haji-common` (.NET shared lib)
- [ ] Clone parent repository ke `C:\Projects\rent-pak-haji`
- [ ] Inisialisasi folder structure:
  ```
  rent-pak-haji/
  ├── microservices/          ← .NET API projects (entry points)
  ├── modularized-code/       ← .NET business logic (Clean Architecture)
  │   ├── be-master-management/
  │   ├── be-vehicle-management/
  │   ├── be-booking-management/
  │   ├── be-journey-management/
  │   ├── be-driver-management/
  │   ├── be-payment-management/
  │   └── be-saga-orchestrator/
  ├── nest-services/          ← NestJS services
  ├── libs/                   ← Git submodule (common library)
  ├── infrastructure/
  │   ├── scripts/schema/     ← SQL schema files ✅
  │   └── mosquitto/          ← MQTT config
  └── docs/                   ← Dokumentasi & diagram
  ```
- [ ] Setup Git submodule untuk common library:
  ```bash
  git submodule add https://github.com/kalfinbagas/rent-pak-haji-common.git libs/common
  git submodule init && git submodule update
  ```

---

## PHASE 4 — Common Library (.NET)
> Shared library yang dipakai semua .NET services. Buat di `libs/common`.

### 4.1 Common.Domain
- [ ] `BaseEntity` — Id (UUID), CreatedAt, UpdatedAt
- [ ] `AuditableEntity` — extends BaseEntity + CreatedBy, ModifiedBy, Version
- [ ] `IDomainEvent` interface
- [ ] `IUnitOfWork` interface

### 4.2 Common.Application
- [ ] `ICommand` / `ICommandHandler<T>` interface (MediatR wrapper)
- [ ] `IQuery<T>` / `IQueryHandler<T>` interface
- [ ] `Result<T>` pattern — success/failure tanpa throw exception
- [ ] `PagedResult<T>` untuk pagination

### 4.3 Common.Broker (RabbitMQ)
- [ ] `IRabbitMqPublisher` — publish event ke exchange
- [ ] `RabbitMqConsumer` base class — auto-create queue + DLQ binding
- [ ] Outbox publisher background service (Coravel scheduler)
- [ ] Event deserializer / serializer (System.Text.Json)

### 4.4 Common.Contracts (Event Payloads — antar service)
- [ ] `SoftBookingCreatedEvent` { BookingOrderId, BookingCode, VehicleType, PoolLocationId, PoolLocationName, StartRentalAt, EndRentalAt, ExpiresAt, NumberOfVehicles, TransactionId }
- [ ] `SoftBookingReleasedEvent` { BookingOrderId, BookingCode, TransactionId }
- [ ] `SoftBookingConvertedEvent` { BookingOrderId, BookingCode, TransactionId }
- [ ] `VehicleAssignedEvent` { VehicleAssignmentId, BookingCode, VehicleId, LicensePlate, VehicleType, VehicleCategory, Brand, Model, DriverId, DriverName, NfcCardUid, PoolLocationId, PoolLocationName, TransactionId }
- [ ] `AssignmentCancelledEvent` { VehicleAssignmentId, BookingCode, TransactionId }
- [ ] `PaymentSuccessEvent` { InvoiceId, BookingOrderId, BookingCode, Amount, TransactionId }
- [ ] `BookingExpiredEvent` { BookingOrderId, BookingCode, TransactionId }
- [ ] `BookingCancelledEvent` { BookingOrderId, BookingCode, CancellationReason, TransactionId }
- [ ] `VehicleDispatchedEvent` { JourneyId, BookingCode, VehicleId, LicensePlate, PoolLocationId, TransactionId }
- [ ] `VehicleReturnedEvent` { JourneyId, BookingCode, VehicleId, LicensePlate, ReturnPoolId, TransactionId }
- [ ] `NotificationRequestedEvent` { EventType, RecipientId, RecipientPhone, RecipientEmail, Channel, Payload, BookingCode }

### 4.5 Build & Verify
- [ ] `dotnet build` semua project di libs/common
- [ ] Tidak ada error

---

## PHASE 5 — .NET Services — Domain & Persistence Layer
> Satu service = satu modul di `modularized-code/`. Setiap modul punya: Entity, Application, Infrastructure, Facade.

### 5.1 Master Service (`be-master-management`)
- [ ] Entity: `PoolLocation`, `Customer`, `NfcCard`, `VehicleDriverPair`, `ApprovalConfiguration`, `ApprovalMatrix`
- [ ] `MasterDbContext` + EF Fluent Configuration
- [ ] Migration: `InitialCreate`
- [ ] `dotnet ef database update`

### 5.2 Vehicle Service (`be-vehicle-management`)
- [ ] Entity: `MasterVehicle`, `VehicleCategory`, `VehicleTransmissionType`, `VehicleMovement`, `VehiclePreparation`, `VehicleTransfer`, `VehicleSoftBooking` (replicated), `VehicleAssignment` (replicated)
- [ ] `VehicleDbContext` + EF Fluent Configuration
- [ ] Migration: `InitialCreate`
- [ ] `dotnet ef database update`

### 5.3 BookingOrder Service (`be-booking-management`)
- [ ] Entity: `BookingOrder`, `BookingOrderDetail`, `VehicleSoftBooking`, `VehicleAssignment`
- [ ] `BookingOrderDbContext` + EF Fluent Configuration
- [ ] Migration: `InitialCreate`
- [ ] `dotnet ef database update`

### 5.4 Journey Service (`be-journey-management`)
- [ ] Entity: `Journey`, `JourneyPoolEvent`
- [ ] `JourneyDbContext` + EF Fluent Configuration
- [ ] Migration: `InitialCreate`
- [ ] `dotnet ef database update`

### 5.5 Driver Service (`be-driver-management`)
- [ ] Entity: `Driver`, `DriverAvailability`
- [ ] `DriverDbContext` + EF Fluent Configuration
- [ ] Migration: `InitialCreate`
- [ ] `dotnet ef database update`

### 5.6 Payment Service (`be-payment-management`)
- [ ] Entity: `Invoice`, `Payment`, `Refund`
- [ ] `PaymentDbContext` + EF Fluent Configuration
- [ ] Migration: `InitialCreate`
- [ ] `dotnet ef database update`

### 5.7 Saga Orchestrator (`be-saga-orchestrator`)
- [ ] Entity: `SagaState`, `SagaStep`
- [ ] `SagaDbContext`
- [ ] Migration: `InitialCreate`
- [ ] `dotnet ef database update`

---

## PHASE 6 — .NET Services — Application Layer (CQRS)

### BookingOrder Service (prioritas pertama)
- [ ] `CreateBookingOrderCommand` + Handler
  - Validate stok (query Vehicle Service via Redis cache atau sync API)
  - INSERT booking_order (status=AWAITING_PAYMENT, payment_expires_at=NOW()+15min)
  - INSERT vehicle_soft_booking per line item
  - INSERT outbox_message → SoftBookingCreatedEvent
- [ ] `ProcessPaymentWebhookCommand` + Handler
  - UPDATE payment → SUCCESS
  - UPDATE booking_order → PAID, paid_at=NOW()
  - UPDATE vehicle_soft_booking → CONVERTED
  - INSERT outbox_message → PaymentSuccessEvent + SoftBookingConvertedEvent
- [ ] `ExpireBookingOrdersJob` (Coravel scheduler, interval: 1 menit)
  - SELECT FROM v_expiring_orders
  - UPDATE status=EXPIRED, expired_at=NOW()
  - UPDATE vehicle_soft_booking status=EXPIRED
  - INSERT outbox_message → BookingExpiredEvent + SoftBookingReleasedEvent
- [ ] `AssignVehicleCommand` + Handler (operator assign kendaraan)
- [ ] `GetBookingOrderQuery` + Handler

### Vehicle / Inventory Service
- [ ] `ReplicateSoftBookingConsumer` — consume SoftBookingCreatedEvent → INSERT replicated vehicle_soft_booking
- [ ] `ReleaseSoftBookingConsumer` — consume SoftBookingReleasedEvent → UPDATE status=EXPIRED
- [ ] `ConvertSoftBookingConsumer` — consume SoftBookingConvertedEvent → UPDATE status=CONVERTED
- [ ] `ReplicateAssignmentConsumer` — consume VehicleAssignedEvent → INSERT replicated vehicle_assignment + UPDATE master_vehicle.status=READY
- [ ] `GetAvailableStockQuery` — hitung stok efektif: AVAILABLE - active soft bookings overlap
- [ ] `UpdateVehicleStatusCommand` + Handler

### Journey Service
- [ ] `CreateJourneyCommand` + Handler (triggered saat VehicleAssignedEvent)
- [ ] `RecordPoolEventCommand` + Handler (NFC gate scan atau manual)
  - Jika POOL_OUT → UPDATE journey.status=IN_PROGRESS, dispatched_at=NOW()
  - Jika POOL_IN → UPDATE journey.status=COMPLETED, returned_at=NOW()
  - INSERT outbox_message → VehicleDispatchedEvent / VehicleReturnedEvent

### Payment Service
- [ ] `GenerateInvoiceCommand` + Handler (triggered saat PaymentSuccessEvent)
- [ ] `CreatePaymentCommand` + Handler (buat VA/QRIS via gateway)
- [ ] `ProcessRefundCommand` + Handler
- [ ] Payment gateway integration (Midtrans / Xendit SDK)
  - [ ] Virtual Account callback endpoint
  - [ ] QRIS callback endpoint

### Master Service
- [ ] `GetAvailableDriversQuery` — filter by pool + date + vehicle type capability
- [ ] `CreateVehicleDriverPairCommand` + Handler (dengan approval workflow)
- [ ] `ProcessApprovalCommand` + Handler

---

## PHASE 7 — .NET Services — API Layer

### Port Mapping

| Service | Port |
|---|---|
| Master API | 5000 |
| Vehicle / Inventory API | 5010 |
| BookingOrder API | 5020 |
| Journey API | 5030 |
| Driver API | 5040 |
| Payment API | 5050 |
| Saga Orchestrator | 5060 |

### Setup per service
- [ ] `dotnet new webapi` untuk setiap microservice entry point di `microservices/`
- [ ] Project reference ke modul business logic di `modularized-code/`
- [ ] `Program.cs` — DI registration (DbContext, MediatR, Coravel, RabbitMQ, Redis, Serilog)
- [ ] `appsettings.Development.json` — connection strings (lihat `.env.example`)
- [ ] Controllers per resource
- [ ] Swagger UI (`/swagger`)
- [ ] Health check endpoint (`/health`)

---

## PHASE 8 — NestJS Services

### 8.1 Notification Service (NestJS + TypeORM)
> Port: 3004 · DB: rpk_notification

- [ ] `nest new notification-service`
- [ ] Install dependencies:
  ```bash
  npm install @nestjs/typeorm typeorm pg
  npm install amqplib @types/amqplib
  npm install @nestjs/config class-validator class-transformer
  npm install nodemailer @types/nodemailer handlebars
  npm install firebase-admin  # untuk FCM push notification
  ```
- [ ] TypeORM entity: `NotificationTemplate`, `NotificationLog`, `DeviceToken`
- [ ] `NotificationConsumer` — consume `NotificationRequestedEvent` dari RabbitMQ
- [ ] `WhatsAppProvider` — kirim via WA Business API (Fonnte / Wablas)
- [ ] `EmailProvider` — kirim via Nodemailer / Mailgun
- [ ] `PushProvider` — kirim via Firebase Admin SDK (FCM)
- [ ] Retry scheduler (exponential backoff, `@nestjs/schedule`)
- [ ] Mustache template renderer — render placeholder `{{booking_code}}` dll

### 8.2 Voucher Service (NestJS + TypeORM)
> Port: 3002 · DB: rpk_master (tabel voucher, special_price)

- [ ] `nest new voucher-service`
- [ ] Install: `@nestjs/typeorm typeorm pg @nestjs/config ioredis`
- [ ] `ValidateVoucherCommand` — cek kode, validity, usage limit, min order
- [ ] `RedeemVoucherCommand` — increment current_usage
- [ ] Redis caching untuk active vouchers

### 8.3 API Gateway / BFF (NestJS)
> Port: 3000 · Proxy ke semua .NET services

- [ ] `nest new api-gateway`
- [ ] Install: `@nestjs/axios http-proxy-middleware`
- [ ] Route proxy ke masing-masing .NET service
- [ ] JWT authentication middleware
- [ ] Rate limiting

### 8.4 Dashboard Service (NestJS + WebSocket)
> Port: 3001 · Real-time dashboard pool & stok

- [ ] `nest new dashboard-service`
- [ ] Install: `@nestjs/websockets @nestjs/platform-socket.io socket.io`
- [ ] RabbitMQ consumer untuk semua domain events
- [ ] WebSocket gateway — broadcast event ke client (real-time update)
- [ ] Pool stock aggregation endpoint

---

## PHASE 9 — RabbitMQ Event Contracts

### Exchanges
- [ ] `rpk.booking.events` (topic) — semua booking events
- [ ] `rpk.inventory.events` (topic) — stok & vehicle events
- [ ] `rpk.payment.events` (topic) — payment events
- [ ] `rpk.journey.events` (topic) — dispatch & return events
- [ ] `rpk.notification.commands` (direct) — kirim notifikasi
- [ ] `rpk.saga.commands` (topic) — saga orchestration
- [ ] `rpk.dlq` (topic) — dead letter queue

### Queues & Bindings
- [ ] `inventory.soft-booking-created` ← binding: `rpk.booking.events` / `soft-booking.created`
- [ ] `inventory.soft-booking-released` ← binding: `rpk.booking.events` / `soft-booking.released`
- [ ] `inventory.soft-booking-converted` ← binding: `rpk.booking.events` / `soft-booking.converted`
- [ ] `inventory.vehicle-assigned` ← binding: `rpk.booking.events` / `vehicle.assigned`
- [ ] `journey.vehicle-assigned` ← binding: `rpk.booking.events` / `vehicle.assigned`
- [ ] `notification.payment-success` ← binding: `rpk.payment.events` / `payment.success`
- [ ] `notification.booking-expired` ← binding: `rpk.booking.events` / `booking.expired`
- [ ] `notification.vehicle-dispatched` ← binding: `rpk.journey.events` / `vehicle.dispatched`
- [ ] Semua queue punya DLQ pasangan → `*.dlq`

---

## PHASE 10 — Testing & Verification

### 10.1 Unit Tests
- [ ] BookingOrder: `CreateBookingOrder` handler — validate stock hold logic
- [ ] BookingOrder: `ExpireBookingOrders` scheduler — validate expiry logic
- [ ] Vehicle: `GetAvailableStock` query — validate soft booking deduction
- [ ] Payment: `ProcessPaymentWebhook` — validate state transitions

### 10.2 Integration Tests
- [ ] End-to-end booking flow:
  1. `POST /api/bookings` → booking created + soft booking ACTIVE
  2. `POST /api/payments` → payment created (VA/QRIS)
  3. Simulate gateway webhook → payment SUCCESS
  4. Verify: booking_order.status=PAID, soft_booking.status=CONVERTED
- [ ] Expiry flow:
  1. Create booking, manipulate `payment_expires_at` ke masa lalu
  2. Trigger scheduler job
  3. Verify: status=EXPIRED, soft_booking.status=EXPIRED

### 10.3 Postman Collection
- [ ] Import collection ke Postman
- [ ] Environment variables: `base_url`, `vehicle_api`, `booking_api`, `payment_api`
- [ ] Test suite per service (Master, Vehicle, Booking, Payment, Journey)

### 10.4 Checklist Final Verifikasi

```bash
# Docker
docker compose ps                        # semua healthy

# Databases
docker exec -it rpk-postgres psql -U rpk_admin -c "\l"

# Services health
curl http://localhost:5010/health        # Vehicle API
curl http://localhost:5020/health        # BookingOrder API
curl http://localhost:5050/health        # Payment API
curl http://localhost:3001               # Dashboard

# RabbitMQ
# Buka http://localhost:15672 → Exchanges tab → cek rpk.*.events
# Buka Queues tab → cek semua queue ada

# Seq
# Buka http://localhost:8081 → cek ada log masuk dari services
```

---

## PHASE 11 — IoT / NFC (Opsional)
> Skip jika belum ada hardware. Semua service lain fully functional tanpa ini.

- [ ] `infrastructure/mosquitto/mosquitto.conf` dibuat
- [ ] Mosquitto container running (port 1883 + 9001)
- [ ] `nest new iot-gateway` (port 3005)
- [ ] Install: `mqtt @types/mqtt amqplib @types/amqplib`
- [ ] MQTT subscriber: topic `rentpakhaji/gate/+/scan`
- [ ] NFC scan handler → validate card → trigger journey pool event
- [ ] Test tanpa hardware:
  ```bash
  # Terminal A - subscribe
  mqtt subscribe -h localhost -t "rentpakhaji/gate/+/scan" -v
  # Terminal B - simulate scan
  mqtt publish -h localhost -t "rentpakhaji/gate/gate-001/scan" \
    -m '{"cardUid":"AB:CD:EF:12","timestamp":"2026-05-09T10:00:00Z"}'
  ```
- [ ] (Hardware) ESP32 + MFRC522 sketch di-upload dan terhubung ke WiFi + MQTT

---

## Port Reference

| Service | Port | Notes |
|---|---|---|
| PostgreSQL | 5432 | Database |
| RabbitMQ AMQP | 5672 | Message broker |
| RabbitMQ UI | 15672 | Management dashboard |
| Redis | 6379 | Cache + distributed lock |
| Seq | 8081 | Log aggregation UI |
| Jaeger | 16686 | Distributed tracing UI |
| pgAdmin | 8080 | Database UI |
| Mosquitto MQTT | 1883 | IoT messaging |
| Master API (.NET) | 5000 | Pool, Customer, NFC, Voucher |
| Vehicle API (.NET) | 5010 | Inventory & stock management |
| BookingOrder API (.NET) | 5020 | Booking, soft booking, assignment |
| Journey API (.NET) | 5030 | Dispatch & return tracking |
| Driver API (.NET) | 5040 | Driver management |
| Payment API (.NET) | 5050 | Invoice, payment, refund |
| Saga API (.NET) | 5060 | Saga orchestrator |
| API Gateway (NestJS) | 3000 | BFF / reverse proxy |
| Dashboard (NestJS) | 3001 | Real-time WebSocket dashboard |
| Voucher (NestJS) | 3002 | Voucher & special price |
| Notification (NestJS) | 3004 | WA, Email, Push |
| IoT Gateway (NestJS) | 3005 | NFC/MQTT bridge |

---

## Troubleshooting

```bash
# Port sudah dipakai
netstat -ano | findstr :5432
taskkill /PID <pid> /F

# Container unhealthy — lihat log
docker compose logs postgres --tail 30
docker compose logs rabbitmq --tail 30

# Reset semua data (hati-hati!)
docker compose down -v
docker compose up -d

# NestJS module not found
rmdir /s /q node_modules
del package-lock.json
npm install

# .NET EF migration error
dotnet ef migrations remove
dotnet ef migrations add InitialCreate --project <Entity> --startup-project <Api>
```

---

*Progress: Phase 0–2 selesai ✅ · Phase 3–11 dalam antrian*
