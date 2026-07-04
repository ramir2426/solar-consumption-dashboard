require "rails_helper"

RSpec.describe MeasurementApi::Client do
  let(:client) { described_class.new(base_url: "https://measurement.example.test") }

  it "parses every interval across every day in the response" do
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

    intervals = client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))

    expect(intervals.size).to eq(3)

    first = intervals.first
    expect(first.starts_at).to eq(Time.iso8601("2026-06-04T00:00:00+02:00"))
    expect(first.ends_at).to eq(Time.iso8601("2026-06-04T00:15:00+02:00"))
    expect(first.value).to eq(BigDecimal("0.4819"))
    expect(first).to be_good_quality
  end

  it "raises RequestFailed on a server error" do
    stub_request(:get, "https://measurement.example.test/values/1234567890/load-profile")
      .with(query: { beginDate: "2026-06-04" })
      .to_return(status: 500, body: "boom")

    expect do
      client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))
    end.to raise_error(MeasurementApi::RequestFailed)
  end

  it "raises RequestFailed when the connection times out" do
    stub_request(:get, "https://measurement.example.test/values/1234567890/load-profile")
      .with(query: { beginDate: "2026-06-04" })
      .to_timeout

    expect do
      client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))
    end.to raise_error(MeasurementApi::RequestFailed)
  end

  it "raises UnexpectedResponse when the body isn't the expected shape" do
    stub_request(:get, "https://measurement.example.test/values/1234567890/load-profile")
      .with(query: { beginDate: "2026-06-04" })
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { "oops" => true }.to_json)

    expect do
      client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))
    end.to raise_error(MeasurementApi::UnexpectedResponse)
  end

  it "raises UnexpectedResponse when an interval is missing required fields" do
    stub_request(:get, "https://measurement.example.test/values/1234567890/load-profile")
      .with(query: { beginDate: "2026-06-04" })
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: [
        { "startDate" => "2026-06-04T00:00:00", "endDate" => "2026-06-05T00:00:00",
          "values" => [ { "value" => 0.1, "quality" => "TRUE" } ] } # missing startDate/endDate
      ].to_json)

    expect do
      client.load_profile(location_id: "1234567890", begin_date: Date.new(2026, 6, 4))
    end.to raise_error(MeasurementApi::UnexpectedResponse)
  end
end
