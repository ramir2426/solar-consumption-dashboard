require "test_helper"

class ReadingTest < ActiveSupport::TestCase
  setup do
    @location = create_consumer.market_location
  end

  test "cannot have two readings starting at the same time for the same location" do
    start = Time.zone.parse("2026-06-04 00:00")
    create_reading(location: @location, starts_at: start, value: 0.5)

    duplicate = @location.readings.build(starts_at: start, ends_at: start + 15.minutes, value: 0.1, quality: "TRUE")
    assert_not duplicate.valid?
  end

  test "good_quality? reflects the raw quality flag from the source system" do
    good = create_reading(location: @location, starts_at: Time.zone.now, value: 0.1, quality: "TRUE")
    bad = create_reading(location: @location, starts_at: Time.zone.now + 15.minutes, value: 0.1, quality: "FALSE")

    assert good.good_quality?
    assert_not bad.good_quality?
  end

  test "good_quality scope only returns TRUE-quality readings" do
    good = create_reading(location: @location, starts_at: Time.zone.now, value: 0.1, quality: "TRUE")
    create_reading(location: @location, starts_at: Time.zone.now + 15.minutes, value: 0.1, quality: "FALSE")

    assert_equal [ good ], @location.readings.good_quality.to_a
  end
end
