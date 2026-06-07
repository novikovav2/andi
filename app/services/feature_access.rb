class FeatureAccess
  FEATURES = %i[
    event_history
    event_photos
    receipt_recognition
  ].freeze

  def self.for_event(event)
    new(event.user)
  end

  def initialize(user)
    @user = user
  end

  def receipt_recognition?
    pro?
  end

  def event_photos?
    pro?
  end

  def event_history?
    user.present?
  end

  def enabled?(feature)
    return false unless FEATURES.include?(feature.to_sym)

    public_send("#{feature}?")
  end

  private
  attr_reader :user

  def pro?
    user&.pro?
  end
end
