require "test_helper"

class LocationTest < ActiveSupport::TestCase
  setup { @consumer = create_consumer }

  test "market location id must be exactly 10 digits" do
    bare_consumer = create_house.consumers.create!(name: "Bare")
    location = Location.new(consumer: bare_consumer, location_type: :market, location_id: "123456789")
    assert_not location.valid?
    assert_includes location.errors[:location_id], "must be exactly 10 digits"

    location.location_id = "1234567890"
    assert location.valid?
  end

  test "market location id rejects non-digit characters" do
    location = Location.new(consumer: create_house.consumers.create!(name: "Bare"),
                             location_type: :market, location_id: "123456789A")
    assert_not location.valid?
  end

  test "metering location id must be exactly 33 characters" do
    bare_consumer = create_house.consumers.create!(name: "Bare")
    location = Location.new(consumer: bare_consumer, location_type: :metering, location_id: "D" * 32)
    assert_not location.valid?
    assert_includes location.errors[:location_id], "is the wrong length (should be 33 characters)"

    location.location_id = "D" * 33
    assert location.valid?
  end

  test "a consumer cannot have two locations of the same type" do
    duplicate = @consumer.locations.build(location_type: :market, location_id: "9999999999")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:location_type], "has already been taken"
  end

  test "location ids are globally unique" do
    other_consumer = create_consumer
    taken_id = @consumer.market_location.location_id

    duplicate = other_consumer.locations.build(location_type: :market, location_id: taken_id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:location_id], "has already been taken"
  end
end
