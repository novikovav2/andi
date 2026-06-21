class Event < ApplicationRecord
  has_many :settlements, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :participants, dependent: :destroy
  belongs_to :user, optional: true
  has_many :receipt_scans, dependent: :destroy
  has_many :event_photos, dependent: :destroy

  validates :title, presence: true
  validates :access_token, presence: true, uniqueness: true
  validates :status, presence: true
  validates :organizer_token, presence: true

  scope :owned_by, ->(token) {
    where(organizer_token: token).order(created_at: :desc)
  }

  scope :active, -> {
    where.not(status: "settled")
  }

  enum :status, {
    draft: "draft",
    unconfirmed: "unconfirmed",
    confirmed: "confirmed",
    settled: "settled"
  }

  before_validation :set_access_token, on: :create

  def mark_unconfirmed!
    record_change!(nil)
  end

  def record_change!(description, affects_calculation: true)
    attributes = {
      last_change_description: description.presence || last_change_description,
      last_change_at: description.present? ? Time.current : last_change_at
    }

    if affects_calculation
      settlements.destroy_all
      attributes[:status] = expenses.none? ? "draft" : "unconfirmed"
      attributes[:locked_at] = nil
    end

    update!(attributes)
  end

  def photos_enabled?
    user&.pro?
  end

  private
  def set_access_token
    self.access_token ||= SecureRandom.urlsafe_base64(24)
  end
end
