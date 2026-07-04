class Reading < ApplicationRecord
  belongs_to :location

  GOOD_QUALITY = "TRUE"

  validates :starts_at, :ends_at, :value, presence: true
  validates :starts_at, uniqueness: { scope: :location_id }

  scope :good_quality, -> { where(quality: GOOD_QUALITY) }
  scope :between, ->(from, to) { where(starts_at: from...to) }

  def good_quality?
    quality == GOOD_QUALITY
  end
end
