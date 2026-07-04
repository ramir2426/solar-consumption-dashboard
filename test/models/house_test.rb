require "test_helper"

class HouseTest < ActiveSupport::TestCase
  test "solar_total and average_daily_solar aggregate across every consumer" do
    house = create_house
    a = create_consumer(house: house, name: "A")
    b = create_consumer(house: house, name: "B")

    a.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 1.0)
    a.daily_aggregates.create!(date: Date.new(2026, 6, 5), solar_total: 1.0)
    b.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 3.0)

    assert_in_delta 5.0, house.solar_total, 0.0001
    # Averaged over calendar days for the house as a whole (2 distinct
    # dates), not per-consumer-day: 5.0 kWh across Jun 4-5 -> 2.5 kWh/day.
    assert_in_delta 2.5, house.average_daily_solar, 0.0001
  end

  test "solar_coverage_ratio is the share of metered consumption covered by solar" do
    house = create_house
    consumer = create_consumer(house: house)
    consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), metering_total: 10.0, solar_total: 2.5)

    assert_in_delta 25.0, house.solar_coverage_ratio, 0.0001
  end

  test "solar_coverage_ratio is nil rather than zero before there's any data" do
    assert_nil create_house.solar_coverage_ratio
  end

  test "timeframe reflects readings across all of a house's consumers" do
    house = create_house
    a = create_consumer(house: house, name: "A")
    b = create_consumer(house: house, name: "B")

    create_reading(location: a.market_location, starts_at: Time.zone.parse("2026-06-04 00:00"), value: 0.1)
    create_reading(location: b.metering_location, starts_at: Time.zone.parse("2026-06-20 23:45"), value: 0.1)

    from, to = house.timeframe
    assert_equal Time.zone.parse("2026-06-04 00:00"), from
    assert_equal Time.zone.parse("2026-06-21 00:00"), to
  end

  test "timeframe is nil for a house with no imported data" do
    assert_nil create_house.timeframe
  end

  test "latest_import returns the most recently created import" do
    house = create_house
    older = house.imports.create!(begin_date: 10.days.ago.to_date)
    newer = house.imports.create!(begin_date: 1.day.ago.to_date)

    assert_equal newer, house.latest_import
    assert_not_equal older, house.latest_import
  end
end
