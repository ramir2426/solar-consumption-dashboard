require "test_helper"

class ConsumersControllerTest < ActionDispatch::IntegrationTest
  test "show renders the daily breakdown for a consumer with data" do
    house = create_house
    consumer = create_consumer(house: house, name: "Apartment A")
    consumer.daily_aggregates.create!(date: Date.new(2026, 6, 4), market_total: 1, metering_total: 2, solar_total: 1, complete: true)
    consumer.daily_aggregates.create!(date: Date.new(2026, 6, 5), market_total: 1, metering_total: 1.5, solar_total: 0.5, complete: false)

    get house_consumer_path(house, consumer)

    assert_response :success
    assert_select "h1", text: "Apartment A"
    assert_select "td", text: /Jun 4, 2026/
    assert_select "svg rect", count: 2
  end

  test "show handles a consumer with nothing imported yet" do
    house = create_house
    consumer = create_consumer(house: house, name: "Brand new")

    get house_consumer_path(house, consumer)

    assert_response :success
    assert_select "p", text: /No data imported yet/
  end

  test "the house dashboard links to each consumer's daily page" do
    house = create_house
    consumer = create_consumer(house: house, name: "Apartment A")

    get house_path(house)

    assert_select "a[href=?]", house_consumer_path(house, consumer), text: "Apartment A"
  end
end
