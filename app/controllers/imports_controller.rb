class ImportsController < ApplicationController
  def create
    house = House.find(params[:house_id])

    if house.consumers.none?
      return redirect_to house_path(house),
        alert: "Add a consumer with a market and metering location before importing data."
    end

    if house.imports.running.exists?
      return redirect_to house_path(house),
        alert: "An import is already running for this house — hang tight, the page updates on its own when it's done."
    end

    import = house.imports.create!(begin_date: begin_date)
    ImportHouseJob.perform_later(import.id)

    redirect_to house_path(house), notice: "Import started from #{import.begin_date} — this page will update live as it runs."
  end

  private

  def begin_date
    raw = params[:begin_date].presence
    return 30.days.ago.to_date unless raw

    parsed = Date.iso8601(raw)
    parsed > Date.current ? Date.current : parsed
  rescue ArgumentError
    30.days.ago.to_date
  end
end
