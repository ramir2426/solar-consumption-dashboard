require "test_helper"

module Solar
  class DailyAggregatorTest < ActiveSupport::TestCase
    setup do
      @consumer = create_consumer
      @date = Date.new(2026, 6, 4)
    end

    test "solar total is the absolute difference between matching intervals" do
      # Metering (real draw) below market (grid-settled) for one interval,
      # above it for the next -- both should still add positively to solar.
      add_reading(:market, "00:00", 0.30)
      add_reading(:metering, "00:00", 0.50)
      add_reading(:market, "00:15", 0.50)
      add_reading(:metering, "00:15", 0.20)

      DailyAggregator.rebuild(@consumer, dates: [ @date ])
      aggregate = @consumer.daily_aggregates.find_by!(date: @date)

      assert_in_delta 0.20 + 0.30, aggregate.solar_total, 0.0001
      assert_in_delta 0.80, aggregate.market_total, 0.0001
      assert_in_delta 0.70, aggregate.metering_total, 0.0001
    end

    test "only intervals reported by both locations are counted" do
      add_reading(:market, "00:00", 0.30)
      add_reading(:metering, "00:00", 0.50)
      add_reading(:market, "00:15", 0.40) # metering never reported this interval

      DailyAggregator.rebuild(@consumer, dates: [ @date ])
      aggregate = @consumer.daily_aggregates.find_by!(date: @date)

      assert_in_delta 0.20, aggregate.solar_total, 0.0001
      assert_equal 2, aggregate.market_reading_count
      assert_equal 1, aggregate.metering_reading_count
      assert_not aggregate.complete
    end

    test "low quality readings are excluded from every total" do
      add_reading(:market, "00:00", 0.30)
      add_reading(:metering, "00:00", 0.50)
      add_reading(:market, "00:15", 0.99, quality: "FALSE")
      add_reading(:metering, "00:15", 0.01, quality: "FALSE")

      DailyAggregator.rebuild(@consumer, dates: [ @date ])
      aggregate = @consumer.daily_aggregates.find_by!(date: @date)

      assert_in_delta 0.20, aggregate.solar_total, 0.0001
      assert_equal 1, aggregate.market_reading_count
      assert_equal 1, aggregate.metering_reading_count
    end

    test "a full day of matched intervals is marked complete" do
      96.times do |i|
        starts_at = @date.beginning_of_day + (i * 15).minutes
        create_reading(location: @consumer.market_location, starts_at: starts_at, value: 0.1)
        create_reading(location: @consumer.metering_location, starts_at: starts_at, value: 0.2)
      end

      DailyAggregator.rebuild(@consumer, dates: [ @date ])
      aggregate = @consumer.daily_aggregates.find_by!(date: @date)

      assert aggregate.complete
      assert_in_delta 96 * 0.1, aggregate.solar_total, 0.001
    end

    test "rebuilding is idempotent" do
      add_reading(:market, "00:00", 0.30)
      add_reading(:metering, "00:00", 0.50)

      2.times { DailyAggregator.rebuild(@consumer, dates: [ @date ]) }

      assert_equal 1, @consumer.daily_aggregates.where(date: @date).count
    end

    test "does nothing when a consumer is missing a location" do
      lonely_consumer = create_house.consumers.create!(name: "No locations yet")

      assert_nothing_raised { DailyAggregator.rebuild(lonely_consumer, dates: [ @date ]) }
      assert_empty lonely_consumer.daily_aggregates
    end

    private

    def add_reading(role, time_of_day, value, quality: "TRUE")
      location = role == :market ? @consumer.market_location : @consumer.metering_location
      starts_at = Time.zone.parse("#{@date} #{time_of_day}")
      create_reading(location: location, starts_at: starts_at, value: value, quality: quality)
    end
  end
end
