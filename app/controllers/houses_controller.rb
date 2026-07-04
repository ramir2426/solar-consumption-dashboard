class HousesController < ApplicationController
  # Sorted worst-coverage-first rather than alphabetically: for a company
  # managing many GGV houses, "which buildings need attention" is a more
  # useful default view than an arbitrary list. Houses with no data yet
  # sort last rather than being read as "0% coverage".
  def index
    @coverage_by_house_id = coverage_by_house_id
    @houses = House.includes(:consumers).order(:name)
                   .sort_by { |house| @coverage_by_house_id[house.id] || Float::INFINITY }
  end

  def show
    @house = House.find(params[:id])
  end

  private

  # One aggregate query across every house instead of calling
  # House#solar_coverage_ratio per row (which would be an N+1 -- two
  # extra queries per house on a page that's about to list all of them).
  def coverage_by_house_id
    rows = ConsumerDailyAggregate
      .joins(consumer: :house)
      .group("houses.id")
      .pluck(
        "houses.id",
        Arel.sql("SUM(consumer_daily_aggregates.solar_total)"),
        Arel.sql("SUM(consumer_daily_aggregates.metering_total)")
      )

    rows.each_with_object({}) do |(house_id, solar_total, metering_total), memo|
      memo[house_id] = metering_total.to_f.zero? ? nil : (solar_total / metering_total * 100).round(1)
    end
  end
end
