require "rails_helper"

RSpec.describe Solar::DailyAggregator do
  let(:consumer) { create_consumer }
  let(:date) { Date.new(2026, 6, 4) }

  def add_reading(role, time_of_day, value, quality: "TRUE")
    location = role == :market ? consumer.market_location : consumer.metering_location
    starts_at = Time.zone.parse("#{date} #{time_of_day}")
    create_reading(location: location, starts_at: starts_at, value: value, quality: quality)
  end

  it "computes the solar total as the absolute difference between matching intervals" do
    # Metering (real draw) below market (grid-settled) for one interval,
    # above it for the next -- both should still add positively to solar.
    add_reading(:market, "00:00", 0.30)
    add_reading(:metering, "00:00", 0.50)
    add_reading(:market, "00:15", 0.50)
    add_reading(:metering, "00:15", 0.20)

    described_class.rebuild(consumer, dates: [ date ])
    aggregate = consumer.daily_aggregates.find_by!(date: date)

    expect(aggregate.solar_total).to be_within(0.0001).of(0.20 + 0.30)
    expect(aggregate.market_total).to be_within(0.0001).of(0.80)
    expect(aggregate.metering_total).to be_within(0.0001).of(0.70)
  end

  it "only counts intervals reported by both locations" do
    add_reading(:market, "00:00", 0.30)
    add_reading(:metering, "00:00", 0.50)
    add_reading(:market, "00:15", 0.40) # metering never reported this interval

    described_class.rebuild(consumer, dates: [ date ])
    aggregate = consumer.daily_aggregates.find_by!(date: date)

    expect(aggregate.solar_total).to be_within(0.0001).of(0.20)
    expect(aggregate.market_reading_count).to eq(2)
    expect(aggregate.metering_reading_count).to eq(1)
    expect(aggregate).not_to be_complete
  end

  it "excludes low quality readings from every total" do
    add_reading(:market, "00:00", 0.30)
    add_reading(:metering, "00:00", 0.50)
    add_reading(:market, "00:15", 0.99, quality: "FALSE")
    add_reading(:metering, "00:15", 0.01, quality: "FALSE")

    described_class.rebuild(consumer, dates: [ date ])
    aggregate = consumer.daily_aggregates.find_by!(date: date)

    expect(aggregate.solar_total).to be_within(0.0001).of(0.20)
    expect(aggregate.market_reading_count).to eq(1)
    expect(aggregate.metering_reading_count).to eq(1)
  end

  it "marks a full day of matched intervals as complete" do
    96.times do |i|
      starts_at = date.beginning_of_day + (i * 15).minutes
      create_reading(location: consumer.market_location, starts_at: starts_at, value: 0.1)
      create_reading(location: consumer.metering_location, starts_at: starts_at, value: 0.2)
    end

    described_class.rebuild(consumer, dates: [ date ])
    aggregate = consumer.daily_aggregates.find_by!(date: date)

    expect(aggregate).to be_complete
    expect(aggregate.solar_total).to be_within(0.001).of(96 * 0.1)
  end

  it "is idempotent when rebuilt twice" do
    add_reading(:market, "00:00", 0.30)
    add_reading(:metering, "00:00", 0.50)

    2.times { described_class.rebuild(consumer, dates: [ date ]) }

    expect(consumer.daily_aggregates.where(date: date).count).to eq(1)
  end

  it "does nothing when a consumer is missing a location" do
    lonely_consumer = create_house.consumers.create!(name: "No locations yet")

    expect { described_class.rebuild(lonely_consumer, dates: [ date ]) }.not_to raise_error
    expect(lonely_consumer.daily_aggregates).to be_empty
  end
end
