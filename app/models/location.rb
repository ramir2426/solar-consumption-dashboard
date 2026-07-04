class Location < ApplicationRecord
  belongs_to :consumer
  has_many :readings, dependent: :destroy

  enum :location_type, { market: 0, metering: 1 }

  # A market location ("Marktlokation") id is a 10-digit number; a
  # metering location ("Messlokation") id is a 33-character string.
  MARKET_ID_PATTERN = /\A\d{10}\z/
  METERING_ID_LENGTH = 33

  validates :location_id, uniqueness: true
  validates :location_type, presence: true, uniqueness: { scope: :consumer_id }
  validate :location_id_matches_its_role

  private

  # A plain :location_id validator can't say *which* location is wrong.
  # That's invisible on its own record, but a Consumer has exactly one
  # market and one metering location on screen at the same time (see the
  # "new consumer" form) -- once this error bubbles up through
  # accepts_nested_attributes_for it reads as just "Locations location
  # must be exactly 10 digits", with no way to tell which of the two
  # fields that's about. Spelling out the role in the message, and
  # attaching it to :base instead of :location_id, avoids that ambiguity
  # both in the bubbled-up summary and (cleanly, with no prefix at all)
  # when read directly off this record for an inline per-field message.
  def location_id_matches_its_role
    return if location_type.blank? # already covered by the presence validation above

    if location_id.blank?
      errors.add(:base, "#{location_type.capitalize} location ID can't be blank")
    elsif market? && location_id !~ MARKET_ID_PATTERN
      errors.add(:base, "Market location ID must be exactly 10 digits")
    elsif metering? && location_id.length != METERING_ID_LENGTH
      errors.add(:base, "Metering location ID must be exactly #{METERING_ID_LENGTH} characters")
    end
  end
end
