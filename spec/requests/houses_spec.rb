require "rails_helper"

RSpec.describe "Houses" do
  describe "GET /houses" do
    it "lists every house" do
      create_house(name: "Musterstraße 12")

      get houses_path

      expect(response).to have_http_status(:success)
      expect(rendered).to have_link("Musterstraße 12")
    end

    it "sorts houses by solar coverage, worst first, with no-data houses last" do
      worst = create_house(name: "Worst House")
      create_consumer(house: worst).daily_aggregates.create!(date: Date.new(2026, 6, 4), metering_total: 10.0, solar_total: 2.0) # 20%

      best = create_house(name: "Best House")
      create_consumer(house: best).daily_aggregates.create!(date: Date.new(2026, 6, 4), metering_total: 10.0, solar_total: 8.0) # 80%

      no_data = create_house(name: "No Data House")

      get houses_path

      positions = [ worst, best, no_data ].map { |house| response.body.index(house.name) }
      expect(positions).to eq(positions.sort)
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

  describe "GET /houses/new" do
    it "renders the form" do
      get new_house_path

      expect(response).to have_http_status(:success)
      expect(rendered).to have_css("input[name='house[name]']")
    end
  end

  describe "POST /houses" do
    it "creates the house and redirects to it" do
      expect do
        post houses_path, params: { house: { name: "Musterstraße 12" } }
      end.to change(House, :count).by(1)

      house = House.last
      expect(house.name).to eq("Musterstraße 12")
      expect(response).to redirect_to(house_path(house))
    end

    it "re-renders the form with errors when invalid" do
      expect do
        post houses_path, params: { house: { name: "" } }
      end.not_to change(House, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(rendered).to have_css(".text-red-700", text: /can't be blank/)
    end
  end

  describe "GET /houses/:id/edit" do
    it "renders the form pre-filled" do
      house = create_house(name: "Am Sonnenhang 4")

      get edit_house_path(house)

      expect(response).to have_http_status(:success)
      expect(rendered).to have_css("input[name='house[name]'][value='Am Sonnenhang 4']")
    end
  end

  describe "PATCH /houses/:id" do
    it "updates the house and redirects to it" do
      house = create_house(name: "Old name")

      patch house_path(house), params: { house: { name: "New name" } }

      expect(house.reload.name).to eq("New name")
      expect(response).to redirect_to(house_path(house))
    end

    it "re-renders the form with errors when invalid" do
      house = create_house(name: "Keep me")

      patch house_path(house), params: { house: { name: "" } }

      expect(house.reload.name).to eq("Keep me")
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
