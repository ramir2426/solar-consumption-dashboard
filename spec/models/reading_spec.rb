require "rails_helper"

RSpec.describe Reading do
  let(:location) { create_consumer.market_location }

  it "cannot have two readings starting at the same time for the same location" do
    start = Time.zone.parse("2026-06-04 00:00")
    create_reading(location: location, starts_at: start, value: 0.5)

    duplicate = location.readings.build(starts_at: start, ends_at: start + 15.minutes, value: 0.1, quality: "TRUE")

    expect(duplicate).not_to be_valid
  end

  it "reflects the raw quality flag from the source system via good_quality?" do
    good = create_reading(location: location, starts_at: Time.zone.now, value: 0.1, quality: "TRUE")
    bad = create_reading(location: location, starts_at: Time.zone.now + 15.minutes, value: 0.1, quality: "FALSE")

    expect(good).to be_good_quality
    expect(bad).not_to be_good_quality
  end

  it "only returns TRUE-quality readings from the good_quality scope" do
    good = create_reading(location: location, starts_at: Time.zone.now, value: 0.1, quality: "TRUE")
    create_reading(location: location, starts_at: Time.zone.now + 15.minutes, value: 0.1, quality: "FALSE")

    expect(location.readings.good_quality.to_a).to eq([ good ])
  end
end
