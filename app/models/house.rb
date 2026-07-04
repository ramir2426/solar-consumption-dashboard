class House < ApplicationRecord
  has_many :consumers, dependent: :destroy
  has_many :imports, dependent: :destroy
  has_many :daily_aggregates, through: :consumers

  validates :name, presence: true

  # Sum of every consumer's solar self-consumption, across whatever
  # date range has been imported so far.
  def solar_total
    daily_aggregates.sum(:solar_total)
  end

  def average_daily_solar
    days = days_with_data
    return 0 if days.zero?

    solar_total / days
  end

  # What share of the house's total metered consumption was covered by
  # its own solar, as a percentage. nil (rather than 0) when there's
  # nothing to divide by yet, so the UI can say "no data" instead of "0%".
  def solar_coverage_ratio
    metering_total = daily_aggregates.sum(:metering_total)
    return nil if metering_total.zero?

    (solar_total / metering_total * 100).round(1)
  end

  # The date range the currently stored readings actually cover, based
  # on the raw interval data rather than the aggregates table, so it
  # stays accurate even for a house whose aggregates haven't rebuilt yet.
  def timeframe
    from, to = Reading.joins(location: :consumer)
                       .where(consumers: { house_id: id })
                       .pick(Arel.sql("MIN(starts_at)"), Arel.sql("MAX(ends_at)"))
    return nil unless from

    [ from.in_time_zone, to.in_time_zone ]
  end

  def latest_import
    imports.order(created_at: :desc).first
  end

  private

  def days_with_data
    daily_aggregates.select(:date).distinct.count
  end
end
