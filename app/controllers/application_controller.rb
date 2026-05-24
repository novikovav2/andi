class ApplicationController < ActionController::Base
  include EventRefreshable

  helper_method :current_organizer_token, :organizer?

  private

  def current_organizer_token
    cookies.permanent.signed[:organizer_token] ||= SecureRandom.urlsafe_base64(32)
  end

  def organizer?(event)
    current_organizer_token.present? &&
      event.organizer_token.present? &&
      ActiveSupport::SecurityUtils.secure_compare(
        current_organizer_token,
        event.organizer_token
      )
  end
end