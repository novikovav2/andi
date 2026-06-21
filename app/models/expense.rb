class Expense < ApplicationRecord
  belongs_to :event
  belongs_to :payer, class_name: "Participant"
  belongs_to :receipt_scan, optional: true

  has_many :expense_shares, dependent: :destroy
  has_many :participants, through: :expense_shares

  validates :title, presence: true
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }

  after_commit :mark_event_unconfirmed

  def weighted_split?
    expense_shares.any? { |share| share.weight != 1 }
  end

  def split_weight_labels
    expense_shares.sort_by(&:created_at).map do |share|
      share.weight.to_s("F").sub(/\.?0+\z/, "")
    end
  end

  private
  def mark_event_unconfirmed
    event.update!(status: "unconfirmed") unless event.unconfirmed?
  end
end
