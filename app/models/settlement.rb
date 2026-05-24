class Settlement < ApplicationRecord
  belongs_to :event
  belongs_to :from_participant, class_name: "Participant"
  belongs_to :to_participant, class_name: "Participant"

  validates :amount_cents, numericality: { greater_than: 0 }
end
