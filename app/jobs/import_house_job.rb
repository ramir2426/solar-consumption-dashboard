# Fetches load-profile data for every consumer in a house and stores it.
#
# Runs one house at a time, but consumers within it are independent of
# each other: if the API call for one consumer fails, the rest still get
# imported, and the failure is reported on the Import record rather than
# losing the whole run. See Import#status (partial vs. failed) and
# Solar::DailyAggregator for what happens to the numbers afterwards.
class ImportHouseJob < ApplicationJob
  queue_as :default

  # Keeps a single INSERT ... ON CONFLICT statement from growing without
  # bound on a long backfill (a first-time import going back a year is
  # ~35k rows per location). 1_000 rows * 5 columns stays comfortably
  # under Postgres's ~65k bind-parameter ceiling per statement, with
  # plenty of headroom, while still being large enough that we're not
  # round-tripping to the database for every single row.
  UPSERT_BATCH_SIZE = 1_000

  def perform(import_id)
    import = Import.find(import_id)
    import.update!(status: :running, started_at: Time.current)

    failures = run(import)

    finish(import, failures)
  rescue => e
    import.update!(status: :failed, finished_at: Time.current, error_message: e.message)
    raise
  end

  private

  def run(import)
    failures = {}

    import.house.consumers.includes(:market_location, :metering_location).find_each do |consumer|
      import_consumer(consumer, import.begin_date)
    rescue StandardError => e
      # Deliberately broad: one bad consumer (missing location, API
      # hiccup, malformed payload) should never take the rest down with it.
      failures[consumer.name] = e.message
    end

    failures
  end

  def finish(import, failures)
    if failures.empty?
      import.update!(status: :completed, finished_at: Time.current)
    else
      all_failed = failures.size == import.house.consumers.count
      import.update!(
        status: all_failed ? :failed : :partial,
        finished_at: Time.current,
        error_message: failures.map { |name, message| "#{name}: #{message}" }.join("\n")
      )
    end
  end

  def import_consumer(consumer, begin_date)
    raise "consumer has no market and/or metering location configured" unless consumer.ready_for_import?

    [ consumer.market_location, consumer.metering_location ].each do |location|
      store_readings(location, begin_date)
    end

    Solar::DailyAggregator.rebuild(consumer, dates: begin_date..Date.current)
  end

  def store_readings(location, begin_date)
    intervals = client.load_profile(location_id: location.location_id, begin_date: begin_date)
    return if intervals.empty?

    intervals.each_slice(UPSERT_BATCH_SIZE) do |batch|
      rows = batch.map do |interval|
        {
          location_id: location.id,
          starts_at: interval.starts_at,
          ends_at: interval.ends_at,
          value: interval.value,
          quality: interval.quality
        }
      end

      Reading.upsert_all(rows, unique_by: %i[location_id starts_at])
    end
  end

  def client
    @client ||= MeasurementApi::Client.new
  end
end
