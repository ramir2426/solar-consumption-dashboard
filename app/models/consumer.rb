class Consumer < ApplicationRecord
  belongs_to :house
  has_many :locations, dependent: :destroy
  has_many :daily_aggregates, class_name: "ConsumerDailyAggregate", dependent: :destroy

  has_one :market_location, -> { market }, class_name: "Location", inverse_of: :consumer
  has_one :metering_location, -> { metering }, class_name: "Location", inverse_of: :consumer

  # Lets the "new consumer" form create the consumer and both of its
  # locations (market + metering) in one submit -- a Consumer isn't
  # really usable without both anyway (see #ready_for_import?).
  accepts_nested_attributes_for :locations

  validates :name, presence: true

  def solar_total
    daily_aggregates.sum(:solar_total)
  end

  def average_daily_solar
    days = daily_aggregates.count
    return 0 if days.zero?

    solar_total / days
  end

  # What share of this consumer's total metered consumption came from
  # solar, as a percentage. nil when there's nothing to divide by yet.
  def solar_coverage_ratio
    metering_total = daily_aggregates.sum(:metering_total)
    return nil if metering_total.zero?

    (solar_total / metering_total * 100).round(1)
  end

  def timeframe
    from, to = Reading.joins(:location)
                       .where(locations: { consumer_id: id })
                       .pick(Arel.sql("MIN(starts_at)"), Arel.sql("MAX(ends_at)"))
    return nil unless from

    [ from.in_time_zone, to.in_time_zone ]
  end

  def ready_for_import?
    market_location.present? && metering_location.present?
  end
end
