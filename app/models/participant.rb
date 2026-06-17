class Participant < ApplicationRecord
  belongs_to :event

  has_many :paid_expenses,
           class_name: "Expense",
           foreign_key: :payer_id,
           dependent: :destroy
  has_many :expense_shares, dependent: :destroy
  has_many :shared_expenses, through: :expense_shares, source: :expense
  has_many :event_photos, dependent: :nullify

  validates :name, presence: true
end
