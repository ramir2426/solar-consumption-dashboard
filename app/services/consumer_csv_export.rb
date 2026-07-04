require "csv"

# Renders a consumer's daily solar-consumption rollup as CSV, so a
# resident (or the ops team) can pull it into a spreadsheet instead of
# copying numbers out of the page by hand.
class ConsumerCsvExport
  HEADERS = [ "Date", "Market total (kWh)", "Metering total (kWh)", "Solar consumption (kWh)", "Complete data?" ].freeze

  def initialize(consumer)
    @consumer = consumer
  end

  def filename
    "#{@consumer.name.parameterize}-daily-solar-consumption.csv"
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << HEADERS
      @consumer.daily_aggregates.chronological.each do |row|
        csv << [ row.date.iso8601, row.market_total, row.metering_total, row.solar_total, row.complete ]
      end
    end
  end
end
