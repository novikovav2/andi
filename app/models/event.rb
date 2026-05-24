class Event < ApplicationRecord
  has_many :settlements, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :participants, dependent: :destroy

  validates :title, presence: true
  validates :access_token, presence: true, uniqueness: true
  validates :status, presence: true
  validates :organizer_token, presence: true

  scope :owned_by, ->(token) {
    where(organizer_token: token).order(created_at: :desc)
  }

  enum :status, {
    draft: "draft",
    unconfirmed: "unconfirmed",
    confirmed: "confirmed",
    settled: "settled"
  }

  before_validation :set_access_token, on: :create

  def mark_unconfirmed!
    return update!(status: "draft", locked_at: nil) if expenses.none?

    settlements.destroy_all
    update!(status: "unconfirmed", locked_at: nil)
  end

  private
  def set_access_token
    self.access_token ||= SecureRandom.urlsafe_base64(24)
  end
end
