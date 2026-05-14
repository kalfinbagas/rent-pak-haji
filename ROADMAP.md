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

## Struktur Monorepo

```
rent-pak-haji/
├── src/
│   └── services/
│       ├── BookingOrder/           ← .NET Clean Architecture
│       │   ├── BookingOrder.Domain/
│       │   ├── BookingOrder.Application/
│       │   ├── BookingOrder.Infrastructure/
│       │   └── BookingOrder.Api/
│       ├── Vehicle/
│       ├── Driver/
│       ├── Journey/
│       ├── Payment/
│       ├── Master/
│       └── Saga/
├── nest-services/
│   ├── notification-service/
│   ├── voucher-service/
│   ├── api-gateway/
│   ├── dashboard-service/
│   └── iot-gateway/
├── libs/
│   └── common/                     ← Git submodule (rent-pak-haji-common)
├── infrastructure/
│   ├── scripts/
│   │   ├── init-db.sql
│   │   └── schema/
│   └── mosquitto/
└── docs/
```

---

## PHASE 0 — Prerequisites (Instalasi Tools) ✅

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
- [x] `rpk_bookingorder_schema.sql` — booking_order + payment_expires_at, detail, soft_booking, assignment, outbox
- [x] `rpk_journey_schema.sql` — journey, journey_pool_event, outbox
- [x] `rpk_driver_schema.sql` — driver, driver_availability, outbox
- [x] `rpk_payment_schema.sql` — invoice, payment (VA + QRIS), refund, outbox
- [x] `rpk_notification_schema.sql` — 3 tabel + 7 seed template (WA, Email, Push)
- [x] Semua 9 database verified di PostgreSQL
- [x] Semua tabel verified per database
- [x] Seed data notification_template verified

---

## PHASE 3 — Repository & Project Structure ✅

- [x] Buat GitHub repository `rent-pak-haji` (main — monorepo)
- [x] Buat GitHub repository `rent-pak-haji-common` (.NET shared lib)
- [x] Git multi-account setup (work global / personal via includeIf)
- [x] SSH key per GitHub account (`id_ed25519_personal` + Host alias `github-personal`)
- [x] Inisialisasi folder structure monorepo
- [x] Git submodule `libs/common` → `rent-pak-haji-common`
- [x] Push main repo ke GitHub
- [x] `.gitignore` dikonfigurasi (.NET + Node + Docker + OS + IDE)

---

## PHASE 4 — Common Library (.NET) ✅

> Shared library di `libs/common` → repo terpisah `rent-pak-haji-common`, di-link sebagai submodule.

### 4.1 Common.Domain ✅
- [x] `BaseEntity` — Id (UUID), DomainEvents list
- [x] `AuditableEntity` — extends BaseEntity + CreatedAt, UpdatedAt, CreatedBy, UpdatedBy, IsActive, Version
- [x] `IDomainEvent` / `DomainEvent` base record (implements INotification)
- [x] `IUnitOfWork` interface

### 4.2 Common.Application ✅
- [x] `ICommand<TResponse>` / `ICommand` interface (MediatR wrapper)
- [x] `ICommandHandler<TCommand, TResponse>` / `ICommandHandler<TCommand>`
- [x] `IQuery<TResponse>` / `IQueryHandler<TQuery, TResponse>`
- [x] `Result<T>` pattern — success/failure tanpa throw exception
- [x] `PagedResult<T>` untuk pagination
- [x] `ValidationBehaviour<TRequest, TResponse>` — MediatR pipeline (FluentValidation)

### 4.3 Common.Infrastructure ✅
- [x] `BaseDbContext` — EF Core + auto audit fields + domain events → outbox
- [x] `OutboxMessage` entity
- [x] `OutboxPublisher<TDbContext>` — background service (polling PENDING messages)

### 4.4 Common.Broker ✅
- [x] `IRabbitMqPublisher` interface
- [x] `RabbitMqPublisher` — concrete implementation (System.Text.Json, persistent delivery)
- [x] `RabbitMqConsumerBase<TMessage>` — base class consumer (auto ack/nack, DLQ-ready)

### 4.5 Common.Contracts ✅
- [x] `SoftBookingCreatedEvent`
- [x] `SoftBookingReleasedEvent`
- [x] `BookingOrderExpiredEvent`
- [x] `PaymentSuccessEvent`
- [x] `PaymentFailedEvent`
- [x] `VehicleAssignmentCreatedEvent`

### 4.6 Build & Push ✅
- [x] `dotnet build RentPakHaji.Common.slnx` — Build succeeded (5 projects)
- [x] Push ke `rent-pak-haji-common` (bin/obj excluded from tracking)
- [x] Submodule reference di main repo diupdate ke commit terbaru

---

## PHASE 5 — .NET Services — Domain & Persistence Layer

> Scaffold di `src/services/`. Setiap service: Domain → Application → Infrastructure → Api.

### 5.1 BookingOrder Service (prioritas pertama)
- [ ] Scaffold solution: `src/services/BookingOrder/`
  ```bash
  dotnet new sln -n BookingOrder
  dotnet new classlib -n BookingOrder.Domain
  dotnet new classlib -n BookingOrder.Application
  dotnet new classlib -n BookingOrder.Infrastructure
  dotnet new webapi -n BookingOrder.Api
  ```
- [ ] Add project references + reference ke `libs/common`
- [ ] Entity: `BookingOrder`, `BookingOrderDetail`, `VehicleSoftBooking`, `VehicleAssignment`
- [ ] `BookingOrderDbContext` extends `BaseDbContext` + Fluent Configuration
- [ ] Migration: `InitialCreate` → `dotnet ef database update`

### 5.2 Vehicle Service
- [ ] Scaffold solution: `src/services/Vehicle/`
- [ ] Entity: `MasterVehicle`, `VehicleCategory`, `VehicleMovement`, `VehiclePreparation`, `VehicleTransfer`, `VehicleSoftBooking` (replicated), `VehicleAssignment` (replicated), `VehicleStandby`
- [ ] `VehicleDbContext` extends `BaseDbContext` + Fluent Configuration
- [ ] Migration: `InitialCreate` → `dotnet ef database update`

### 5.3 Driver Service
- [ ] Scaffold solution: `src/services/Driver/`
- [ ] Entity: `Driver`, `DriverAvailability`
- [ ] `DriverDbContext` extends `BaseDbContext` + Fluent Configuration
- [ ] Migration: `InitialCreate` → `dotnet ef database update`

### 5.4 Journey Service
- [ ] Scaffold solution: `src/services/Journey/`
- [ ] Entity: `Journey`, `JourneyPoolEvent`
- [ ] `JourneyDbContext` extends `BaseDbContext` + Fluent Configuration
- [ ] Migration: `InitialCreate` → `dotnet ef database update`

### 5.5 Payment Service
- [ ] Scaffold solution: `src/services/Payment/`
- [ ] Entity: `Invoice`, `Payment`, `Refund`
- [ ] `PaymentDbContext` extends `BaseDbContext` + Fluent Configuration
- [ ] Migration: `InitialCreate` → `dotnet ef database update`

### 5.6 Master Service
- [ ] Scaffold solution: `src/services/Master/`
- [ ] Entity: `PoolLocation`, `Customer`, `NfcCard`, `VehicleDriverPair`, `ApprovalMatrix`
- [ ] `MasterDbContext` extends `BaseDbContext` + Fluent Configuration
- [ ] Migration: `InitialCreate` → `dotnet ef database update`

### 5.7 Saga Orchestrator
- [ ] Scaffold solution: `src/services/Saga/`
- [ ] Entity: `SagaState`, `SagaStep`
- [ ] `SagaDbContext` extends `BaseDbContext`
- [ ] Migration: `InitialCreate` → `dotnet ef database update`

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
  - INSERT outbox_message → BookingOrderExpiredEvent + SoftBookingReleasedEvent
- [ ] `AssignVehicleCommand` + Handler (operator assign kendaraan)
- [ ] `GetBookingOrderQuery` + Handler

### Vehicle Service
- [ ] `ReplicateSoftBookingConsumer` — consume SoftBookingCreatedEvent
- [ ] `ReleaseSoftBookingConsumer` — consume SoftBookingReleasedEvent
- [ ] `ConvertSoftBookingConsumer` — consume PaymentSuccessEvent
- [ ] `ReplicateAssignmentConsumer` — consume VehicleAssignmentCreatedEvent
- [ ] `GetAvailableStockQuery` — hitung stok efektif: AVAILABLE - active soft bookings overlap

### Journey Service
- [ ] `CreateJourneyCommand` + Handler (triggered saat VehicleAssignmentCreatedEvent)
- [ ] `RecordPoolEventCommand` + Handler (NFC gate scan atau manual)

### Payment Service
- [ ] `GenerateInvoiceCommand` + Handler
- [ ] `CreatePaymentCommand` + Handler (buat VA/QRIS via gateway)
- [ ] `ProcessRefundCommand` + Handler
- [ ] Payment gateway integration (Midtrans / Xendit)

### Master Service
- [ ] `GetAvailableDriversQuery`
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
- [ ] `Program.cs` — DI registration (DbContext, MediatR, Coravel, RabbitMQ, Redis, Serilog, OpenTelemetry)
- [ ] `appsettings.Development.json` — connection strings
- [ ] Controllers per resource
- [ ] Swagger UI (`/swagger`)
- [ ] Health check endpoint (`/health`)

---

## PHASE 8 — NestJS Services

### 8.1 Notification Service (port 3004)
- [ ] `nest new notification-service`
- [ ] TypeORM entity: `NotificationTemplate`, `NotificationLog`, `DeviceToken`
- [ ] `NotificationConsumer` — consume `NotificationRequestedEvent`
- [ ] WhatsApp / Email / FCM push provider
- [ ] Mustache template renderer

### 8.2 Voucher Service (port 3002)
- [ ] `nest new voucher-service`
- [ ] `ValidateVoucherCommand`, `RedeemVoucherCommand`
- [ ] Redis caching untuk active vouchers

### 8.3 API Gateway / BFF (port 3000)
- [ ] `nest new api-gateway`
- [ ] Route proxy ke semua .NET services
- [ ] JWT authentication middleware + rate limiting

### 8.4 Dashboard Service (port 3001)
- [ ] `nest new dashboard-service`
- [ ] WebSocket gateway — broadcast domain events ke client
- [ ] Pool stock aggregation endpoint

---

## PHASE 9 — RabbitMQ Event Contracts

### Exchanges
- [ ] `rpk.booking` (topic)
- [ ] `rpk.vehicle` (topic)
- [ ] `rpk.payment` (topic)
- [ ] `rpk.journey` (topic)
- [ ] `rpk.notification` (direct)
- [ ] Dead letter exchange: `rpk.dlq`

### Queue Bindings
- [ ] `vehicle.soft-booking-created` ← `rpk.booking` / `booking.soft-booking.created`
- [ ] `vehicle.soft-booking-released` ← `rpk.booking` / `booking.soft-booking.released`
- [ ] `journey.assignment-created` ← `rpk.vehicle` / `vehicle.assignment.created`
- [ ] `notification.payment-success` ← `rpk.payment` / `payment.success`
- [ ] `notification.booking-expired` ← `rpk.booking` / `booking.order.expired`
- [ ] Semua queue punya DLQ pasangan

---

## PHASE 10 — Testing & Verification

### 10.1 Unit Tests
- [ ] BookingOrder: `CreateBookingOrder` handler — validate stock hold logic
- [ ] BookingOrder: `ExpireBookingOrders` scheduler — validate expiry logic
- [ ] Vehicle: `GetAvailableStock` query — validate soft booking deduction

### 10.2 Integration Tests
- [ ] End-to-end booking flow (POST booking → payment webhook → CONFIRMED)
- [ ] Expiry flow (manipulate payment_expires_at → trigger scheduler → EXPIRED)

### 10.3 Postman Collection
- [ ] Collection per service (Master, Vehicle, Booking, Payment, Journey)
- [ ] Environment: `base_url`, service-specific URLs

---

## PHASE 11 — IoT / NFC (Opsional)
> Skip jika belum ada hardware. Semua service lain fully functional tanpa ini.

- [ ] `nest new iot-gateway` (port 3005)
- [ ] MQTT subscriber: topic `rentpakhaji/gate/+/scan`
- [ ] NFC scan handler → validate card → trigger journey pool event
- [ ] (Hardware) ESP32 + MFRC522 sketch

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
| Master API (.NET) | 5000 | Pool, Customer, NFC |
| Vehicle API (.NET) | 5010 | Inventory & stock management |
| BookingOrder API (.NET) | 5020 | Booking, soft booking, assignment |
| Journey API (.NET) | 5030 | Dispatch & return tracking |
| Driver API (.NET) | 5040 | Driver management |
| Payment API (.NET) | 5050 | Invoice, payment, refund |
| Saga API (.NET) | 5060 | Saga orchestrator |
| API Gateway (NestJS) | 3000 | BFF / reverse proxy |
| Dashboard (NestJS) | 3001 | Real-time WebSocket |
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

# Reset semua data (hati-hati!)
docker compose down -v && docker compose up -d

# .NET EF migration error
dotnet ef migrations remove
dotnet ef migrations add InitialCreate

# NestJS module not found
rmdir /s /q node_modules && npm install
```

---

*Progress: Phase 0–4 selesai ✅ · Phase 5–11 dalam antrian*
