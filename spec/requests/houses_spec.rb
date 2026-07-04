require "rails_helper"

RSpec.describe "Houses" do
  describe "GET /houses" do
    it "lists every house" do
      create_house(name: "Musterstraße 12")

      get houses_path

      expect(response).to have_http_status(:success)
      expect(rendered).to have_link("Musterstraße 12")
    end
  end

  describe "GET /houses/:id" do
    it "renders consumer stats, house totals, and the import form" do
      house = create_house(name: "Am Sonnenhang 4")
      consumer = create_consumer(house: house, name: "Apartment A")
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 1.5)

      get house_path(house)

      expect(response).to have_http_status(:success)
      expect(rendered).to have_css("td", text: "Apartment A")
      expect(rendered).to have_css("input[type=submit][value='Import data from API']")
    end

    it "renders a house with no consumers yet without blowing up" do
      house = create_house(name: "Empty house")

      get house_path(house)

      expect(response).to have_http_status(:success)
      expect(rendered).to have_css("p", text: "No data imported yet")
    end
  end
end
