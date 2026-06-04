class User < ApplicationRecord
  has_secure_password

  has_many :events, dependent: :nullify

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  enum :plan, {
    free: "free",
    pro: "pro"
  }
end
