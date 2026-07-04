require "test_helper"

module MeasurementApi
  class ClientTest < ActiveSupport::TestCase
    setup do
      @client = Client.new(base_url: "https://measurement.example.test")
    end

    test "parses every interval across every day in the response" do
      stub_request(:get, "https://measurement.example.test/values/1234567890/load-profile")
        .with(query: { beginDate: "2026-06-04" })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: [
          {
            "locationId" => ":location_id", # the mock API doesn't reliably echo this back
            "startDate" => "2026-06-04T00:00:00",
            "endDate" => "2026-06-05T00:00:00",
            "values" => [
              { "value" => 0.4819, "quality" => "TRUE", "startDate" => "2026-06-04T00:00:00+02:00", "endDate" => "2026-06-04T00:15:00+02:00" },
              { "value" => 0.3293, "quality" => "TRUE", "startDate" => "2026-06-04T00:15:00+02:00", "endDate" => "2026-06-04T00:30:00+02:00" }
            ]
          },
          {
            "startDate" => "2026-06-05T00:00:00",
            "endDate" => "2026-06-06T00:00:00",
            "values" => [
              { "value" => 0.1, "quality" => "TRUE", "startDate" => "2026-06-05T00:00:00+02:00", "endDate" => "2026-06-05T00:15:00+02:00" }
            ]
          }
        ].to_json)

      intervals = @client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))

      assert_equal 3, intervals.size
      first = intervals.first
      assert_equal Time.iso8601("2026-06-04T00:00:00+02:00"), first.starts_at
      assert_equal Time.iso8601("2026-06-04T00:15:00+02:00"), first.ends_at
      assert_equal BigDecimal("0.4819"), first.value
      assert first.good_quality?
    end

    test "raises RequestFailed on a server error" do
      stub_request(:get, "https://measurement.example.test/values/1234567890/load-profile")
        .with(query: { beginDate: "2026-06-04" })
        .to_return(status: 500, body: "boom")

      assert_raises(RequestFailed) do
        @client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))
      end
    end

    test "raises RequestFailed when the connection times out" do
      stub_request(:get, "https://measurement.example.test/values/1234567890/load-profile")
        .with(query: { beginDate: "2026-06-04" })
        .to_timeout

      assert_raises(RequestFailed) do
        @client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))
      end
    end

    test "raises UnexpectedResponse when the body isn't the expected shape" do
      stub_request(:get, "https://measurement.example.test/values/1234567890/load-profile")
        .with(query: { beginDate: "2026-06-04" })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { "oops" => true }.to_json)

      assert_raises(UnexpectedResponse) do
        @client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))
      end
    end

    test "raises UnexpectedResponse when an interval is missing required fields" do
      stub_request(:get, "https://measurement.example.test/values/1234567890/load-profile")
        .with(query: { beginDate: "2026-06-04" })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: [
          { "startDate" => "2026-06-04T00:00:00", "endDate" => "2026-06-05T00:00:00",
            "values" => [ { "value" => 0.1, "quality" => "TRUE" } ] } # missing startDate/endDate
        ].to_json)

      assert_raises(UnexpectedResponse) do
        @client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))
      end
    end
  end
end
