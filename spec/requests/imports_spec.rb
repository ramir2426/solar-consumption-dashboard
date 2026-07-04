require "rails_helper"

RSpec.describe "Imports" do
  describe "POST /houses/:house_id/imports" do
    it "enqueues the import job and redirects back to the house" do
      house = create_house

      expect do
        post house_imports_path(house), params: { begin_date: "2026-06-04" }
      end.to have_enqueued_job(ImportHouseJob).and change { house.imports.count }.by(1)

      expect(response).to redirect_to(house_path(house))
      expect(house.imports.last.begin_date).to eq(Date.new(2026, 6, 4))
    end

    it "falls back to 30 days ago instead of erroring on an invalid begin_date" do
      house = create_house

      post house_imports_path(house), params: { begin_date: "not-a-date" }

      expect(response).to redirect_to(house_path(house))
      expect(house.imports.last.begin_date).to eq(30.days.ago.to_date)
    end

    it "clamps a future begin_date to today" do
      house = create_house

      post house_imports_path(house), params: { begin_date: 5.days.from_now.to_date.iso8601 }

      expect(house.imports.last.begin_date).to eq(Date.current)
    end
  end
end
