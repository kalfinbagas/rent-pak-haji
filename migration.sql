CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE TABLE booking_order (
        id uuid NOT NULL,
        booking_code character varying(20) NOT NULL,
        status character varying(30) NOT NULL,
        customer_id uuid NOT NULL,
        customer_name character varying(150) NOT NULL,
        customer_phone character varying(20) NOT NULL,
        customer_email character varying(150),
        service_type character varying(20) NOT NULL,
        vehicle_type character varying(20) NOT NULL,
        vehicle_category character varying(30),
        number_of_vehicles integer NOT NULL,
        start_rental_at timestamp with time zone NOT NULL,
        end_rental_at timestamp with time zone NOT NULL,
        duration_days integer,
        with_driver_duration_hours integer,
        is_out_of_town boolean NOT NULL,
        daily_rate numeric(18,2) NOT NULL,
        subtotal_rental numeric(18,2) NOT NULL,
        subtotal_amount numeric(18,2) NOT NULL,
        tax_amount numeric(18,2) NOT NULL,
        total_amount numeric(18,2) NOT NULL,
        voucher_code character varying(50),
        voucher_discount numeric(18,2) NOT NULL,
        has_special_price boolean NOT NULL,
        assigned_vehicle_id uuid,
        vehicle_registration_number character varying(15),
        vehicle_brand character varying(50),
        vehicle_model character varying(50),
        vehicle_color character varying(30),
        assigned_driver_id uuid,
        driver_name character varying(150),
        driver_phone character varying(20),
        idempotency_key character varying(100) NOT NULL,
        transaction_id character varying(100) NOT NULL,
        payment_expires_at timestamp with time zone NOT NULL,
        paid_at timestamp with time zone,
        confirmed_at timestamp with time zone,
        completed_at timestamp with time zone,
        expired_at timestamp with time zone,
        cancelled_at timestamp with time zone,
        cancellation_reason text,
        operator_notes text,
        created_at timestamp with time zone NOT NULL,
        "CreatedBy" text,
        updated_at timestamp with time zone,
        "UpdatedBy" text,
        is_active boolean NOT NULL,
        version integer NOT NULL,
        CONSTRAINT "PK_booking_order" PRIMARY KEY (id)
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE TABLE outbox_message (
        "Id" uuid NOT NULL,
        "EventType" character varying(200) NOT NULL,
        "Payload" text NOT NULL,
        "Status" character varying(20) NOT NULL,
        "CreatedAt" timestamp with time zone NOT NULL,
        "PublishedAt" timestamp with time zone,
        "ErrorMessage" text,
        "RetryCount" integer NOT NULL,
        CONSTRAINT "PK_outbox_message" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE TABLE booking_order_detail (
        id uuid NOT NULL,
        booking_order_id uuid NOT NULL,
        detail_type character varying(5) NOT NULL,
        scheduled_at timestamp with time zone NOT NULL,
        timezone character varying(60) NOT NULL,
        expedition_type character varying(20) NOT NULL,
        pool_location_id uuid NOT NULL,
        pool_location_name character varying(150) NOT NULL,
        address text,
        city character varying(100),
        district character varying(100),
        latitude numeric(11,8),
        longitude numeric(11,8),
        expedition_fee numeric(18,2) NOT NULL,
        created_at timestamp with time zone NOT NULL,
        CONSTRAINT "PK_booking_order_detail" PRIMARY KEY (id),
        CONSTRAINT "FK_booking_order_detail_booking_order_booking_order_id" FOREIGN KEY (booking_order_id) REFERENCES booking_order (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE TABLE vehicle_soft_booking (
        id uuid NOT NULL,
        booking_order_id uuid NOT NULL,
        booking_code character varying(20) NOT NULL,
        vehicle_type character varying(20) NOT NULL,
        pool_location_id uuid NOT NULL,
        pool_location_name character varying(150) NOT NULL,
        start_rental_at timestamp with time zone NOT NULL,
        end_rental_at timestamp with time zone NOT NULL,
        number_of_vehicles integer NOT NULL,
        expires_at timestamp with time zone NOT NULL,
        status character varying(20) NOT NULL,
        sequence integer NOT NULL,
        transaction_id character varying(100) NOT NULL,
        created_at timestamp with time zone NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        CONSTRAINT "PK_vehicle_soft_booking" PRIMARY KEY (id),
        CONSTRAINT "FK_vehicle_soft_booking_booking_order_booking_order_id" FOREIGN KEY (booking_order_id) REFERENCES booking_order (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE TABLE vehicle_assignment (
        id uuid NOT NULL,
        booking_order_id uuid NOT NULL,
        booking_detail_id uuid NOT NULL,
        booking_code character varying(20) NOT NULL,
        vehicle_id uuid NOT NULL,
        license_plate character varying(15) NOT NULL,
        vehicle_type character varying(20) NOT NULL,
        vehicle_category character varying(30),
        brand character varying(50) NOT NULL,
        model character varying(50) NOT NULL,
        vehicle_year integer,
        color character varying(30),
        driver_id uuid,
        driver_name character varying(150),
        driver_phone character varying(20),
        nfc_card_uid character varying(50),
        dispatch_pool_id uuid NOT NULL,
        dispatch_pool_name character varying(150) NOT NULL,
        return_pool_id uuid,
        return_pool_name character varying(150),
        assigned_at timestamp with time zone NOT NULL,
        dispatched_at timestamp with time zone,
        returned_at timestamp with time zone,
        status character varying(20) NOT NULL,
        assignment_status smallint NOT NULL,
        sequence integer NOT NULL,
        release_reason_type smallint,
        release_reason_note text,
        released_at timestamp with time zone,
        released_by character varying(100),
        transaction_id character varying(100) NOT NULL,
        created_at timestamp with time zone NOT NULL,
        updated_at timestamp with time zone NOT NULL,
        CONSTRAINT "PK_vehicle_assignment" PRIMARY KEY (id),
        CONSTRAINT "FK_vehicle_assignment_booking_order_booking_order_id" FOREIGN KEY (booking_order_id) REFERENCES booking_order (id) ON DELETE CASCADE,
        CONSTRAINT "FK_vehicle_assignment_booking_order_detail_booking_detail_id" FOREIGN KEY (booking_detail_id) REFERENCES booking_order_detail (id) ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE UNIQUE INDEX "IX_booking_order_booking_code" ON booking_order (booking_code);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE UNIQUE INDEX "IX_booking_order_idempotency_key" ON booking_order (idempotency_key);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE UNIQUE INDEX "IX_booking_order_detail_booking_order_id_detail_type" ON booking_order_detail (booking_order_id, detail_type);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE INDEX "IX_outbox_message_Status_CreatedAt" ON outbox_message ("Status", "CreatedAt") WHERE status = 'PENDING';
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE INDEX "IX_vehicle_assignment_booking_detail_id" ON vehicle_assignment (booking_detail_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE INDEX "IX_vehicle_assignment_booking_order_id" ON vehicle_assignment (booking_order_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE INDEX "IX_vehicle_assignment_status" ON vehicle_assignment (status);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE INDEX "IX_vehicle_assignment_vehicle_id" ON vehicle_assignment (vehicle_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE INDEX "IX_vehicle_soft_booking_booking_order_id" ON vehicle_soft_booking (booking_order_id);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE INDEX "IX_vehicle_soft_booking_expires_at" ON vehicle_soft_booking (expires_at);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE INDEX "IX_vehicle_soft_booking_pool_location_id_vehicle_type" ON vehicle_soft_booking (pool_location_id, vehicle_type);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    CREATE INDEX "IX_vehicle_soft_booking_status" ON vehicle_soft_booking (status);
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20260515134542_InitialCreate') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20260515134542_InitialCreate', '10.0.8');
    END IF;
END $EF$;
COMMIT;

