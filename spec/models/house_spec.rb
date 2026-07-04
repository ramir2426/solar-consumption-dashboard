require "rails_helper"

RSpec.describe House do
  describe "#solar_total and #average_daily_solar" do
    it "aggregate across every consumer" do
      house = create_house
      a = create_consumer(house: house, name: "A")
      b = create_consumer(house: house, name: "B")

      a.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 1.0)
      a.daily_aggregates.create!(date: Date.new(2026, 6, 5), solar_total: 1.0)
      b.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 3.0)

      expect(house.solar_total).to be_within(0.0001).of(5.0)
      # Averaged over calendar days for the house as a whole (2 distinct
      # dates), not per-consumer-day: 5.0 kWh across Jun 4-5 -> 2.5 kWh/day.
      expect(house.average_daily_solar).to be_within(0.0001).of(2.5)
    end
  end

  describe "#solar_coverage_ratio" do
    it "is the share of metered consumption covered by solar" do
      house = create_house
      consumer = create_consumer(house: house)
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), metering_total: 10.0, solar_total: 2.5)

      expect(house.solar_coverage_ratio).to be_within(0.0001).of(25.0)
    end

    it "is nil rather than zero before there's any data" do
      expect(create_house.solar_coverage_ratio).to be_nil
    end
  end

  describe "#timeframe" do
    it "reflects readings across all of a house's consumers" do
      house = create_house
      a = create_consumer(house: house, name: "A")
      b = create_consumer(house: house, name: "B")

      create_reading(location: a.market_location, starts_at: Time.zone.parse("2026-06-04 00:00"), value: 0.1)
      create_reading(location: b.metering_location, starts_at: Time.zone.parse("2026-06-20 23:45"), value: 0.1)

      from, to = house.timeframe

      expect(from).to eq(Time.zone.parse("2026-06-04 00:00"))
      expect(to).to eq(Time.zone.parse("2026-06-21 00:00"))
    end

    it "is nil for a house with no imported data" do
      expect(create_house.timeframe).to be_nil
    end
  end

  describe "#latest_import" do
    it "returns the most recently created import" do
      house = create_house
      older = house.imports.create!(begin_date: 10.days.ago.to_date)
      newer = house.imports.create!(begin_date: 1.day.ago.to_date)

      expect(house.latest_import).to eq(newer)
      expect(house.latest_import).not_to eq(older)
    end
  end
end
