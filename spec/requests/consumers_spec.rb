require "rails_helper"

RSpec.describe "Consumers" do
  describe "GET /houses/:house_id/consumers/:id" do
    it "renders the daily breakdown for a consumer with data" do
      house = create_house
      consumer = create_consumer(house: house, name: "Apartment A")
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), market_total: 1, metering_total: 2, solar_total: 1, complete: true)
      consumer.daily_aggregates.create!(date: Date.new(2026, 6, 5), market_total: 1, metering_total: 1.5, solar_total: 0.5, complete: false)

      get house_consumer_path(house, consumer)

      expect(response).to have_http_status(:success)
      expect(rendered).to have_css("h1", text: "Apartment A")
      expect(rendered).to have_css("td", text: "Jun 4, 2026")
      expect(rendered).to have_css("svg rect", count: 2)
    end

    it "handles a consumer with nothing imported yet" do
      house = create_house
      consumer = create_consumer(house: house, name: "Brand new")

      get house_consumer_path(house, consumer)

      expect(response).to have_http_status(:success)
      expect(rendered).to have_css("p", text: "No data imported yet")
    end

    it "is linked to from the house dashboard" do
      house = create_house
      consumer = create_consumer(house: house, name: "Apartment A")

      get house_path(house)

      expect(rendered).to have_link("Apartment A", href: house_consumer_path(house, consumer))
    end

    context "with format: :csv" do
      it "exports the daily rollup" do
        house = create_house
        consumer = create_consumer(house: house, name: "Apartment A")
        consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), market_total: 1, metering_total: 2.5, solar_total: 1.5, complete: true)

        get house_consumer_path(house, consumer, format: :csv)

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to match(/apartment-a/)
        expect(response.body).to include("2026-06-04,1.0,2.5,1.5,true")
      end
    end
  end
end
