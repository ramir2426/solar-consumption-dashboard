require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  test "creating an import enqueues the job and redirects back to the house" do
    house = create_house

    assert_enqueued_with(job: ImportHouseJob) do
      assert_difference -> { house.imports.count }, 1 do
        post house_imports_path(house), params: { begin_date: "2026-06-04" }
      end
    end

    assert_redirected_to house_path(house)
    assert_equal Date.new(2026, 6, 4), house.imports.last.begin_date
  end

  test "an invalid begin_date falls back to 30 days ago instead of erroring" do
    house = create_house

    post house_imports_path(house), params: { begin_date: "not-a-date" }

    assert_redirected_to house_path(house)
    assert_equal 30.days.ago.to_date, house.imports.last.begin_date
  end

  test "a future begin_date is clamped to today" do
    house = create_house

    post house_imports_path(house), params: { begin_date: 5.days.from_now.to_date.iso8601 }

    assert_equal Date.current, house.imports.last.begin_date
  end
end
