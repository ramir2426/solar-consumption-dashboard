class ConsumersController < ApplicationController
  def show
    @house = House.find(params[:house_id])
    @consumer = @house.consumers.find(params[:id])
    @daily_aggregates = @consumer.daily_aggregates.chronological
  end
end
