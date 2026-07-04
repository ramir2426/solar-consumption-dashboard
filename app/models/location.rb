class Location < ApplicationRecord
  belongs_to :consumer
  has_many :readings, dependent: :destroy

  enum :location_type, { market: 0, metering: 1 }

  # A market location ("Marktlokation") id is a 10-digit number; a
  # metering location ("Messlokation") id is a 33-character string.
  MARKET_ID_PATTERN = /\A\d{10}\z/
  METERING_ID_LENGTH = 33

  validates :location_id, presence: true, uniqueness: true
  validates :location_id, format: { with: MARKET_ID_PATTERN, message: "must be exactly 10 digits" }, if: :market?
  validates :location_id, length: { is: METERING_ID_LENGTH }, if: :metering?
  validates :location_type, uniqueness: { scope: :consumer_id }
end
