require "test_helper"

class ConsumerTest < ActiveSupport::TestCase
  test "solar_total sums the daily aggregates" do
    consumer = create_consumer
    consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 1.5)
    consumer.daily_aggregates.create!(date: Date.new(2026, 6, 5), solar_total: 2.5)

    assert_in_delta 4.0, consumer.solar_total, 0.0001
  end

  test "average_daily_solar divides by the number of days with data" do
    consumer = create_consumer
    consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 1.0)
    consumer.daily_aggregates.create!(date: Date.new(2026, 6, 5), solar_total: 3.0)

    assert_in_delta 2.0, consumer.average_daily_solar, 0.0001
  end

  test "average_daily_solar is zero without any imported days" do
    assert_equal 0, create_consumer.average_daily_solar
  end

  test "ready_for_import? requires both a market and a metering location" do
    consumer = create_consumer
    assert consumer.ready_for_import?

    consumer.metering_location.destroy!
    assert_not consumer.reload.ready_for_import?
  end

  test "timeframe spans the earliest start to the latest end across both locations" do
    consumer = create_consumer
    create_reading(location: consumer.market_location, starts_at: Time.zone.parse("2026-06-04 00:00"), value: 0.1)
    create_reading(location: consumer.metering_location, starts_at: Time.zone.parse("2026-06-10 23:45"), value: 0.1)

    from, to = consumer.timeframe
    assert_equal Time.zone.parse("2026-06-04 00:00"), from
    assert_equal Time.zone.parse("2026-06-11 00:00"), to
  end
end
