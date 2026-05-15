using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BookingOrder.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "booking_order",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_code = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    customer_id = table.Column<Guid>(type: "uuid", nullable: false),
                    customer_name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    customer_phone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    customer_email = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                    service_type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    vehicle_type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    vehicle_category = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    number_of_vehicles = table.Column<int>(type: "integer", nullable: false),
                    start_rental_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    end_rental_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    duration_days = table.Column<int>(type: "integer", nullable: true),
                    with_driver_duration_hours = table.Column<int>(type: "integer", nullable: true),
                    is_out_of_town = table.Column<bool>(type: "boolean", nullable: false),
                    daily_rate = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    subtotal_rental = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    subtotal_amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    tax_amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    total_amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    voucher_code = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    voucher_discount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    has_special_price = table.Column<bool>(type: "boolean", nullable: false),
                    assigned_vehicle_id = table.Column<Guid>(type: "uuid", nullable: true),
                    vehicle_registration_number = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: true),
                    vehicle_brand = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    vehicle_model = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    vehicle_color = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    assigned_driver_id = table.Column<Guid>(type: "uuid", nullable: true),
                    driver_name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                    driver_phone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    idempotency_key = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    transaction_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    payment_expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    paid_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    confirmed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    expired_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cancelled_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cancellation_reason = table.Column<string>(type: "text", nullable: true),
                    operator_notes = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedBy = table.Column<string>(type: "text", nullable: true),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    UpdatedBy = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    version = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_booking_order", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "outbox_message",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    EventType = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Payload = table.Column<string>(type: "text", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PublishedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ErrorMessage = table.Column<string>(type: "text", nullable: true),
                    RetryCount = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_outbox_message", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "booking_order_detail",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    detail_type = table.Column<string>(type: "character varying(5)", maxLength: 5, nullable: false),
                    scheduled_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    timezone = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    expedition_type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    pool_location_id = table.Column<Guid>(type: "uuid", nullable: false),
                    pool_location_name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    address = table.Column<string>(type: "text", nullable: true),
                    city = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    district = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    latitude = table.Column<decimal>(type: "numeric(11,8)", precision: 11, scale: 8, nullable: true),
                    longitude = table.Column<decimal>(type: "numeric(11,8)", precision: 11, scale: 8, nullable: true),
                    expedition_fee = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_booking_order_detail", x => x.id);
                    table.ForeignKey(
                        name: "FK_booking_order_detail_booking_order_booking_order_id",
                        column: x => x.booking_order_id,
                        principalTable: "booking_order",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "vehicle_soft_booking",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_code = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    vehicle_type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    pool_location_id = table.Column<Guid>(type: "uuid", nullable: false),
                    pool_location_name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    start_rental_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    end_rental_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    number_of_vehicles = table.Column<int>(type: "integer", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    sequence = table.Column<int>(type: "integer", nullable: false),
                    transaction_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_vehicle_soft_booking", x => x.id);
                    table.ForeignKey(
                        name: "FK_vehicle_soft_booking_booking_order_booking_order_id",
                        column: x => x.booking_order_id,
                        principalTable: "booking_order",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "vehicle_assignment",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_detail_id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_code = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    vehicle_id = table.Column<Guid>(type: "uuid", nullable: false),
                    license_plate = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: false),
                    vehicle_type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    vehicle_category = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    brand = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    model = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    vehicle_year = table.Column<int>(type: "integer", nullable: true),
                    color = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    driver_id = table.Column<Guid>(type: "uuid", nullable: true),
                    driver_name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                    driver_phone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    nfc_card_uid = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    dispatch_pool_id = table.Column<Guid>(type: "uuid", nullable: false),
                    dispatch_pool_name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    return_pool_id = table.Column<Guid>(type: "uuid", nullable: true),
                    return_pool_name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                    assigned_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    dispatched_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    returned_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    assignment_status = table.Column<short>(type: "smallint", nullable: false),
                    sequence = table.Column<int>(type: "integer", nullable: false),
                    release_reason_type = table.Column<short>(type: "smallint", nullable: true),
                    release_reason_note = table.Column<string>(type: "text", nullable: true),
                    released_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    released_by = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    transaction_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_vehicle_assignment", x => x.id);
                    table.ForeignKey(
                        name: "FK_vehicle_assignment_booking_order_booking_order_id",
                        column: x => x.booking_order_id,
                        principalTable: "booking_order",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_vehicle_assignment_booking_order_detail_booking_detail_id",
                        column: x => x.booking_detail_id,
                        principalTable: "booking_order_detail",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_booking_order_booking_code",
                table: "booking_order",
                column: "booking_code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_booking_order_idempotency_key",
                table: "booking_order",
                column: "idempotency_key",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_booking_order_detail_booking_order_id_detail_type",
                table: "booking_order_detail",
                columns: new[] { "booking_order_id", "detail_type" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_outbox_message_Status_CreatedAt",
                table: "outbox_message",
                columns: new[] { "Status", "CreatedAt" },
                filter: "\"Status\" = 'PENDING'");

            migrationBuilder.CreateIndex(
                name: "IX_vehicle_assignment_booking_detail_id",
                table: "vehicle_assignment",
                column: "booking_detail_id");

            migrationBuilder.CreateIndex(
                name: "IX_vehicle_assignment_booking_order_id",
                table: "vehicle_assignment",
                column: "booking_order_id");

            migrationBuilder.CreateIndex(
                name: "IX_vehicle_assignment_status",
                table: "vehicle_assignment",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "IX_vehicle_assignment_vehicle_id",
                table: "vehicle_assignment",
                column: "vehicle_id");

            migrationBuilder.CreateIndex(
                name: "IX_vehicle_soft_booking_booking_order_id",
                table: "vehicle_soft_booking",
                column: "booking_order_id");

            migrationBuilder.CreateIndex(
                name: "IX_vehicle_soft_booking_expires_at",
                table: "vehicle_soft_booking",
                column: "expires_at");

            migrationBuilder.CreateIndex(
                name: "IX_vehicle_soft_booking_pool_location_id_vehicle_type",
                table: "vehicle_soft_booking",
                columns: new[] { "pool_location_id", "vehicle_type" });

            migrationBuilder.CreateIndex(
                name: "IX_vehicle_soft_booking_status",
                table: "vehicle_soft_booking",
                column: "status");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "outbox_message");

            migrationBuilder.DropTable(
                name: "vehicle_assignment");

            migrationBuilder.DropTable(
                name: "vehicle_soft_booking");

            migrationBuilder.DropTable(
                name: "booking_order_detail");

            migrationBuilder.DropTable(
                name: "booking_order");
        }
    }
}
