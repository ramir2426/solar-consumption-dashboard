module Solar
  # Rebuilds ConsumerDailyAggregate rows for one consumer, for a given set
  # of dates, from the raw readings we already have in the database.
  #
  # Solar self-consumption for a single 15-minute interval is defined by
  # the assignment as "the difference of the values of the two locations".
  # We treat the metering location as the consumer's real physical draw
  # and the market location as what's actually settled through the grid,
  # so in a real GGV setup metering >= market and the gap is what came
  # from the shared solar system. We still take the absolute value here
  # rather than trusting the sign, because this mock API hands back
  # independent random numbers for each location on every call -- the two
  # series have no real relationship to each other the way genuine
  # metering data would. See the README's "Domain assumptions" section.
  #
  # Only intervals present on *both* locations for the same timestamp are
  # counted, and only where the source marked the reading as good quality
  # (quality == "TRUE"); a day is flagged `complete: false` when the two
  # locations don't fully agree on which intervals were reported, so the
  # UI can be upfront about a number being based on partial data.
  class DailyAggregator
    INTERVALS_PER_DAY = 24 * 60 / 15 # 96 quarter-hour slots

    def self.rebuild(consumer, dates:)
      new(consumer, dates).rebuild
    end

    def initialize(consumer, dates)
      @consumer = consumer
      @dates = dates.to_a
    end

    def rebuild
      return if market_location.nil? || metering_location.nil?

      @dates.each { |date| rebuild_date(date) }
    end

    private

    attr_reader :consumer, :dates

    def market_location
      @market_location ||= consumer.market_location
    end

    def metering_location
      @metering_location ||= consumer.metering_location
    end

    def rebuild_date(date)
      market_values = good_readings_by_start(market_location, date)
      metering_values = good_readings_by_start(metering_location, date)
      shared_timestamps = market_values.keys & metering_values.keys

      solar_total = shared_timestamps.sum do |timestamp|
        (metering_values[timestamp] - market_values[timestamp]).abs
      end

      ConsumerDailyAggregate.upsert(
        {
          consumer_id: consumer.id,
          date: date,
          market_total: market_values.values.sum,
          metering_total: metering_values.values.sum,
          solar_total: solar_total,
          market_reading_count: market_values.size,
          metering_reading_count: metering_values.size,
          complete: market_values.size == metering_values.size && market_values.size >= INTERVALS_PER_DAY
        },
        unique_by: %i[consumer_id date]
      )
    end

    def good_readings_by_start(location, date)
      location.readings
              .good_quality
              .between(date.beginning_of_day, date.next_day.beginning_of_day)
              .pluck(:starts_at, :value)
              .to_h
    end
  end
end
