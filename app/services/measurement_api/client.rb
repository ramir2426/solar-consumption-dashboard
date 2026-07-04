require "faraday"
require "faraday/retry"
require "bigdecimal"

module MeasurementApi
  Error = Class.new(StandardError)
  RequestFailed = Class.new(Error)
  UnexpectedResponse = Class.new(Error)

  # Thin wrapper around the mock load-profile measurement API described in
  # the assignment:
  #
  #   GET /values/:location_id/load-profile?beginDate=YYYY-MM-DD
  #
  # It replies with one JSON object per calendar day, from beginDate up
  # through today, each holding an array of 15-minute interval readings.
  #
  # One thing worth calling out: the mock API does not reliably echo back
  # the location id you asked for -- in testing it sometimes responded
  # with the literal string ":location_id" in the `locationId` field
  # instead of substituting it. So this client never reads `locationId`
  # out of the response body; the caller already knows which location it
  # asked for and is responsible for attaching the returned intervals to
  # the right record.
  class Client
    DEFAULT_BASE_URL = "https://mock-measurement-api-8fbe027730b7.herokuapp.com"
    OPEN_TIMEOUT = 5
    TIMEOUT = 15

    Interval = Struct.new(:starts_at, :ends_at, :value, :quality, keyword_init: true) do
      def good_quality?
        quality == "TRUE"
      end
    end

    def initialize(base_url: ENV.fetch("MEASUREMENT_API_BASE_URL", DEFAULT_BASE_URL))
      @connection = Faraday.new(url: base_url) do |f|
        f.request :retry, max: 2, interval: 0.5, backoff_factor: 2,
                          exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ]
        f.response :json, content_type: /\bjson$/
        f.options.open_timeout = OPEN_TIMEOUT
        f.options.timeout = TIMEOUT
        f.adapter Faraday.default_adapter
      end
    end

    # Returns a flat Array of Interval structs, oldest first.
    def load_profile(location_id:, begin_date:)
      response = get_with_error_handling(location_id, begin_date)
      parse(response.body, location_id: location_id)
    end

    private

    def get_with_error_handling(location_id, begin_date)
      @connection.get("/values/#{location_id}/load-profile", beginDate: begin_date.iso8601).tap do |response|
        unless response.success?
          raise RequestFailed, "GET load-profile for #{location_id} returned HTTP #{response.status}"
        end
      end
    rescue Faraday::Error => e
      raise RequestFailed, "GET load-profile for #{location_id} failed: #{e.class}: #{e.message}"
    end

    def parse(body, location_id:)
      raise UnexpectedResponse, "expected a JSON array, got #{body.class} for #{location_id}" unless body.is_a?(Array)

      body.flat_map do |day|
        Array(day["values"]).map { |raw| build_interval(raw) }
      end
    rescue KeyError, TypeError, ArgumentError => e
      raise UnexpectedResponse, "malformed load-profile payload for #{location_id}: #{e.message}"
    end

    def build_interval(raw)
      Interval.new(
        starts_at: Time.iso8601(raw.fetch("startDate")),
        ends_at: Time.iso8601(raw.fetch("endDate")),
        value: BigDecimal(raw.fetch("value").to_s),
        quality: raw["quality"]
      )
    end
  end
end
