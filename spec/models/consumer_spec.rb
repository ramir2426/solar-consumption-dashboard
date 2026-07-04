require "rails_helper"

RSpec.describe Consumer do
  describe "#solar_total" do
    it "sums the daily aggregates" do
      consumer = create_consumer
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 1.5)
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 5), solar_total: 2.5)

      expect(consumer.solar_total).to be_within(0.0001).of(4.0)
    end
  end

  describe "#average_daily_solar" do
    it "divides by the number of days with data" do
      consumer = create_consumer
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 1.0)
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 5), solar_total: 3.0)

      expect(consumer.average_daily_solar).to be_within(0.0001).of(2.0)
    end

    it "is zero without any imported days" do
      expect(create_consumer.average_daily_solar).to eq(0)
    end
  end

  describe "#solar_coverage_ratio" do
    it "is the share of metered consumption covered by solar" do
      consumer = create_consumer
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), metering_total: 4.0, solar_total: 1.0)
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 5), metering_total: 6.0, solar_total: 2.0)

      # 3.0 kWh solar out of 10.0 kWh total metered consumption
      expect(consumer.solar_coverage_ratio).to be_within(0.0001).of(30.0)
    end

    it "is nil rather than zero before there's any data" do
      expect(create_consumer.solar_coverage_ratio).to be_nil
    end
  end

  describe "#ready_for_import?" do
    it "requires both a market and a metering location" do
      consumer = create_consumer
      expect(consumer).to be_ready_for_import

      consumer.metering_location.destroy!
      expect(consumer.reload).not_to be_ready_for_import
    end
  end

  describe "#timeframe" do
    it "spans the earliest start to the latest end across both locations" do
      consumer = create_consumer
      create_reading(location: consumer.market_location, starts_at: Time.zone.parse("2026-06-04 00:00"), value: 0.1)
      create_reading(location: consumer.metering_location, starts_at: Time.zone.parse("2026-06-10 23:45"), value: 0.1)

      from, to = consumer.timeframe

      expect(from).to eq(Time.zone.parse("2026-06-04 00:00"))
      expect(to).to eq(Time.zone.parse("2026-06-11 00:00"))
    end
  end
end
