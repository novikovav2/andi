class Expense < ApplicationRecord
  belongs_to :event
  belongs_to :payer, class_name: "Participant"

  has_many :expense_shares, dependent: :destroy
  has_many :participants, through: :expense_shares

  validates :title, presence: true
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }

  after_commit :mark_event_unconfirmed

  private
  def mark_event_unconfirmed
    event.update!(status: "unconfirmed") unless event.unconfirmed?
  end
end
