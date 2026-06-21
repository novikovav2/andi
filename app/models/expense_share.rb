class ExpenseShare < ApplicationRecord
  belongs_to :expense
  belongs_to :participant

  validates :participant_id, uniqueness: { scope: :expense_id }
  validates :weight, numericality: { greater_than_or_equal_to: 0 }

  after_commit :mark_event_unconfirmed

  private
  def mark_event_unconfirmed
    expense.event.update!(status: "unconfirmed") unless expense.event.unconfirmed?
  end
end
