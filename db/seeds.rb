# Demo data for local development.
#
# Location ids only need to be *plausible*, not real: a market location
# is 10 digits, a metering location is 33 characters (see Location's
# validations), and the mock measurement API returns data regardless of
# which id you send it.
def metering_id(suffix)
  prefix = "DE0001454577"
  prefix + suffix.to_s.rjust(33 - prefix.length, "0")
end

houses = [
  {
    name: "Musterstraße 12, Berlin",
    consumers: [
      { name: "Apartment 1 (ground floor)", market_id: "5011000001", metering_id: metering_id(1) },
      { name: "Apartment 2 (first floor)", market_id: "5011000002", metering_id: metering_id(2) },
      { name: "Apartment 3 (second floor)", market_id: "5011000003", metering_id: metering_id(3) }
    ]
  },
  {
    name: "Am Sonnenhang 4, München",
    consumers: [
      { name: "Apartment A", market_id: "5022000001", metering_id: metering_id(4) },
      { name: "Apartment B", market_id: "5022000002", metering_id: metering_id(5) }
    ]
  }
]

houses.each do |house_attrs|
  house = House.find_or_create_by!(name: house_attrs[:name])

  house_attrs[:consumers].each do |consumer_attrs|
    consumer = house.consumers.find_or_create_by!(name: consumer_attrs[:name])

    Location.find_or_create_by!(consumer: consumer, location_type: :market) do |location|
      location.location_id = consumer_attrs[:market_id]
    end

    Location.find_or_create_by!(consumer: consumer, location_type: :metering) do |location|
      location.location_id = consumer_attrs[:metering_id]
    end
  end
end

puts "Seeded #{House.count} houses, #{Consumer.count} consumers, #{Location.count} locations."
puts 'Next: open a house and click "Import data from API".'
