# A precomputed per-consumer, per-day rollup of solar self-consumption.
#
# The house and consumer detail pages read from this table instead of
# summing raw 15-minute `readings` on every request. See
# Solar::DailyAggregator, which is what keeps it up to date, and the
# "Performance" section of the README for why this table exists.
class ConsumerDailyAggregate < ApplicationRecord
  belongs_to :consumer

  validates :date, presence: true, uniqueness: { scope: :consumer_id }

  scope :chronological, -> { order(:date) }
end
