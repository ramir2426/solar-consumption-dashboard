class HousesController < ApplicationController
  def index
    @houses = House.order(:name)
  end

  def show
    @house = House.find(params[:id])
  end
end
