class ConsumersController < ApplicationController
  before_action :set_house

  def show
    @consumer = @house.consumers.find(params[:id])
    @daily_aggregates = @consumer.daily_aggregates.chronological

    respond_to do |format|
      format.html
      format.csv { send_csv_export }
    end
  end

  def new
    @consumer = @house.consumers.new
    build_blank_locations(@consumer)
  end

  def create
    @consumer = @house.consumers.new(consumer_params)

    if @consumer.save
      redirect_to house_path(@house), notice: "#{@consumer.name} added."
    else
      build_blank_locations(@consumer) if @consumer.locations.empty?
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    consumer = @house.consumers.find(params[:id])
    consumer.destroy
    redirect_to house_path(@house), notice: "#{consumer.name} and all of its imported data were deleted."
  end

  private

  def set_house
    @house = House.find(params[:house_id])
  end

  # The form always shows exactly one market + one metering field --
  # a Consumer only ever has these two, never a variable list -- so we
  # seed both up front rather than building a generic "add another"
  # nested-attributes UI that doesn't apply here.
  def build_blank_locations(consumer)
    consumer.locations.build(location_type: :market)
    consumer.locations.build(location_type: :metering)
  end

  def consumer_params
    params.require(:consumer).permit(:name, locations_attributes: %i[id location_type location_id])
  end

  def send_csv_export
    export = ConsumerCsvExport.new(@consumer)
    send_data export.to_csv, filename: export.filename, type: Mime[:csv]
  end
end
