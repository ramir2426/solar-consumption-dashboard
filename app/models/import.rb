class Import < ApplicationRecord
  belongs_to :house

  # partial: some consumers imported fine, others didn't (see error_message)
  enum :status, { pending: 0, running: 1, completed: 2, failed: 3, partial: 4 }

  validates :begin_date, presence: true

  after_update_commit :broadcast_status

  def duration
    return nil unless started_at && finished_at

    finished_at - started_at
  end

  private

  # Pushes a fresh copy of the house dashboard down the wire whenever this
  # import's status changes, so anyone with the page open watches it go
  # pending -> running -> completed without refreshing.
  def broadcast_status
    broadcast_replace_to(
      house,
      target: ActionView::RecordIdentifier.dom_id(house, :dashboard),
      partial: "houses/dashboard",
      locals: { house: house.reload }
    )
  end
end
