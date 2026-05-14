using BookingOrder.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BookingOrder.Infrastructure.Persistence.Configurations;

internal sealed class BookingOrderDetailConfiguration
    : IEntityTypeConfiguration<BookingOrderDetail>
{
    public void Configure(EntityTypeBuilder<BookingOrderDetail> builder)
    {
        builder.ToTable("booking_order_detail");

        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).HasColumnName("id");

        builder.Property(x => x.BookingOrderId).HasColumnName("booking_order_id").IsRequired();
        builder.Property(x => x.DetailType).HasColumnName("detail_type").HasMaxLength(5).IsRequired();
        builder.Property(x => x.ScheduledAt).HasColumnName("scheduled_at").IsRequired();
        builder.Property(x => x.Timezone).HasColumnName("timezone").HasMaxLength(60).IsRequired();

        builder.Property(x => x.ExpeditionType).HasColumnName("expedition_type")
            .HasConversion<string>().HasMaxLength(20).IsRequired();

        builder.Property(x => x.PoolLocationId).HasColumnName("pool_location_id").IsRequired();
        builder.Property(x => x.PoolLocationName).HasColumnName("pool_location_name").HasMaxLength(150).IsRequired();

        builder.Property(x => x.Address).HasColumnName("address");
        builder.Property(x => x.City).HasColumnName("city").HasMaxLength(100);
        builder.Property(x => x.District).HasColumnName("district").HasMaxLength(100);
        builder.Property(x => x.Latitude).HasColumnName("latitude").HasPrecision(11, 8);
        builder.Property(x => x.Longitude).HasColumnName("longitude").HasPrecision(11, 8);
        builder.Property(x => x.ExpeditionFee).HasColumnName("expedition_fee").HasPrecision(18, 2).IsRequired();

        builder.Property(x => x.CreatedAt).HasColumnName("created_at");

        // 1 START + 1 END per order
        builder.HasIndex(x => new { x.BookingOrderId, x.DetailType }).IsUnique();
    }
}
