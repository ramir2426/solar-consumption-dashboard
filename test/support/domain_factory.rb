# Small hand-rolled builders for the House -> Consumer -> Location ->
# Reading object graph, used instead of fixtures across the suite.
module DomainFactory
  def create_house(name: "Test House")
    House.create!(name: name)
  end

  def create_consumer(house: nil, name: "Test Consumer")
    house ||= create_house
    consumer = house.consumers.create!(name: name)
    consumer.locations.create!(location_type: :market, location_id: next_market_id)
    consumer.locations.create!(location_type: :metering, location_id: next_metering_id)
    consumer
  end

  def create_reading(location:, starts_at:, value:, quality: "TRUE")
    location.readings.create!(
      starts_at: starts_at,
      ends_at: starts_at + 15.minutes,
      value: value,
      quality: quality
    )
  end

  private

  def next_market_id
    @market_id_seq = (@market_id_seq || 5_000_000_000) + 1
    @market_id_seq.to_s
  end

  def next_metering_id
    @metering_id_seq = (@metering_id_seq || 0) + 1
    "DE#{@metering_id_seq.to_s.rjust(31, '0')}"
  end
end
