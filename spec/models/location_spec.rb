require "rails_helper"

RSpec.describe Location do
  let(:consumer) { create_consumer }

  it "requires a market location id to be exactly 10 digits" do
    bare_consumer = create_house.consumers.create!(name: "Bare")
    location = Location.new(consumer: bare_consumer, location_type: :market, location_id: "123456789")

    expect(location).not_to be_valid
    # On :base (not :location_id) and spelling out "Market" so a form
    # showing both a market and a metering field at once isn't ambiguous
    # about which one this error belongs to.
    expect(location.errors[:base]).to include("Market location ID must be exactly 10 digits")

    location.location_id = "1234567890"
    expect(location).to be_valid
  end

  it "rejects non-digit characters in a market location id" do
    location = Location.new(consumer: create_house.consumers.create!(name: "Bare"),
                             location_type: :market, location_id: "123456789A")

    expect(location).not_to be_valid
  end

  it "requires a metering location id to be exactly 33 characters" do
    bare_consumer = create_house.consumers.create!(name: "Bare")
    location = Location.new(consumer: bare_consumer, location_type: :metering, location_id: "D" * 32)

    expect(location).not_to be_valid
    expect(location.errors[:base]).to include("Metering location ID must be exactly 33 characters")

    location.location_id = "D" * 33
    expect(location).to be_valid
  end

  it "says which role is missing when a location id is blank" do
    location = Location.new(consumer: create_house.consumers.create!(name: "Bare"), location_type: :metering, location_id: "")

    expect(location).not_to be_valid
    expect(location.errors[:base]).to include("Metering location ID can't be blank")
  end

  it "does not let a consumer have two locations of the same type" do
    duplicate = consumer.locations.build(location_type: :market, location_id: "9999999999")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:location_type]).to include("has already been taken")
  end

  it "requires location ids to be globally unique" do
    other_consumer = create_consumer
    taken_id = consumer.market_location.location_id

    duplicate = other_consumer.locations.build(location_type: :market, location_id: taken_id)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:location_id]).to include("has already been taken")
  end
end
