class ReceiptScan < ApplicationRecord
  belongs_to :event
  has_many :expenses, dependent: :restrict_with_error

  has_one_attached :image

  enum :status, {
    pending: "pending",
    processing: "processing",
    ready: "ready",
    failed: "failed"
  }, default: :pending

  validates :image, presence: true
  validates :status, presence: true
end
