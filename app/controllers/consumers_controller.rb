class ConsumersController < ApplicationController
  def show
    @house = House.find(params[:house_id])
    @consumer = @house.consumers.find(params[:id])
    @daily_aggregates = @consumer.daily_aggregates.chronological

    respond_to do |format|
      format.html
      format.csv { send_csv_export }
    end
  end

  private

  def send_csv_export
    export = ConsumerCsvExport.new(@consumer)
    send_data export.to_csv, filename: export.filename, type: Mime[:csv]
  end
end
