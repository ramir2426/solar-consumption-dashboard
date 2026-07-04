require "test_helper"

class ImportHouseJobTest < ActiveSupport::TestCase
  setup do
    @house = create_house
    @begin_date = Date.new(2026, 6, 4)
  end

  test "imports both locations for every consumer and marks the import completed" do
    a = create_consumer(house: @house, name: "Apartment A")
    b = create_consumer(house: @house, name: "Apartment B")
    [ a, b ].each { |c| stub_ok(c.market_location, base_value: 0.2) }
    [ a, b ].each { |c| stub_ok(c.metering_location, base_value: 0.5) }

    import = @house.imports.create!(begin_date: @begin_date)
    ImportHouseJob.perform_now(import.id)

    import.reload
    assert import.completed?
    assert_nil import.error_message
    assert_equal 2, a.market_location.readings.count
    assert_equal 2, a.metering_location.readings.count
    assert a.daily_aggregates.exists?
    assert_in_delta 0.3 * 2, a.solar_total, 0.0001 # |0.5 - 0.2| per interval, 2 intervals
  end

  test "one failing consumer doesn't stop the others, and the import is only partial" do
    healthy = create_consumer(house: @house, name: "Healthy")
    broken = create_consumer(house: @house, name: "Broken")
    stub_ok(healthy.market_location, base_value: 0.2)
    stub_ok(healthy.metering_location, base_value: 0.5)
    stub_request(:get, %r{/values/#{broken.market_location.location_id}/load-profile})
      .to_return(status: 503)
    stub_ok(broken.metering_location, base_value: 0.5)

    import = @house.imports.create!(begin_date: @begin_date)
    ImportHouseJob.perform_now(import.id)

    import.reload
    assert import.partial?
    assert_includes import.error_message, "Broken"
    assert healthy.market_location.readings.exists?
    assert_not broken.market_location.readings.exists?
  end

  test "is marked failed when every consumer fails" do
    consumer = create_consumer(house: @house)
    stub_request(:get, %r{/values/.+/load-profile}).to_return(status: 500)

    import = @house.imports.create!(begin_date: @begin_date)
    ImportHouseJob.perform_now(import.id)

    assert import.reload.failed?
  end

  test "reports a consumer with a missing location instead of raising" do
    incomplete = @house.consumers.create!(name: "No metering location yet")
    incomplete.locations.create!(location_type: :market, location_id: "5000000099")
    healthy = create_consumer(house: @house, name: "Healthy")
    stub_ok(healthy.market_location, base_value: 0.1)
    stub_ok(healthy.metering_location, base_value: 0.4)

    import = @house.imports.create!(begin_date: @begin_date)
    ImportHouseJob.perform_now(import.id)

    import.reload
    assert import.partial?
    assert_includes import.error_message, "No metering location yet"
    assert healthy.daily_aggregates.exists?
  end

  test "a backfill bigger than one upsert batch stores every interval exactly once" do
    consumer = create_consumer(house: @house)
    interval_count = ImportHouseJob::UPSERT_BATCH_SIZE + 250 # forces at least 2 batches

    [ consumer.market_location, consumer.metering_location ].each do |location|
      stub_many(location, count: interval_count)
    end

    import = @house.imports.create!(begin_date: @begin_date)
    ImportHouseJob.perform_now(import.id)

    assert import.reload.completed?
    assert_equal interval_count, consumer.market_location.readings.count
    assert_equal interval_count, consumer.metering_location.readings.count
  end

  private

  # Two 15-minute intervals on @begin_date, both at `base_value`, so tests
  # can pick values that make the expected solar diff obvious.
  def stub_ok(location, base_value:)
    values = [ 0, 1 ].map do |i|
      start = (@begin_date.beginning_of_day + (i * 15).minutes).iso8601
      finish = (@begin_date.beginning_of_day + ((i + 1) * 15).minutes).iso8601
      { "value" => base_value, "quality" => "TRUE", "startDate" => start, "endDate" => finish }
    end

    stub_request(:get, %r{/values/#{location.location_id}/load-profile})
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [ { "startDate" => @begin_date.iso8601, "endDate" => (@begin_date + 1).iso8601, "values" => values } ].to_json
      )
  end

  # `count` consecutive 15-minute intervals, all in a single day chunk
  # (the mock API itself always returns one chunk per calendar day, but
  # nothing in the client or job assumes that -- this just keeps the
  # fixture simple).
  def stub_many(location, count:)
    values = Array.new(count) do |i|
      start = (@begin_date.beginning_of_day + (i * 15).minutes).iso8601
      finish = (@begin_date.beginning_of_day + ((i + 1) * 15).minutes).iso8601
      { "value" => 0.1, "quality" => "TRUE", "startDate" => start, "endDate" => finish }
    end

    stub_request(:get, %r{/values/#{location.location_id}/load-profile})
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: [ { "startDate" => @begin_date.iso8601, "endDate" => (@begin_date + 1).iso8601, "values" => values } ].to_json
      )
  end
end
