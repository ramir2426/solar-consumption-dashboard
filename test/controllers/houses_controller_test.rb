require "test_helper"

class HousesControllerTest < ActionDispatch::IntegrationTest
  test "index lists every house" do
    create_house(name: "Musterstraße 12")

    get houses_path

    assert_response :success
    assert_select "a", text: /Musterstraße 12/
  end

  test "show renders consumer stats, house totals, and the import form" do
    house = create_house(name: "Am Sonnenhang 4")
    consumer = create_consumer(house: house, name: "Apartment A")
    consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), solar_total: 1.5)

    get house_path(house)

    assert_response :success
    assert_select "td", text: /Apartment A/
    assert_select "input[type=submit][value=?]", "Import data from API"
  end

  test "show renders a house with no consumers yet without blowing up" do
    house = create_house(name: "Empty house")

    get house_path(house)

    assert_response :success
    assert_select "p", text: /No data imported yet/
  end
end
