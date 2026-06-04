class ApplicationController < ActionController::Base
  include EventRefreshable

  helper_method :current_organizer_token, :organizer?
  helper_method :current_user, :signed_in?

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

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def signed_in?
    current_user.present?
  end

  def sign_in(user)
    session[:user_id] = user.id
  end

  def sign_out
    session.delete(:user_id)
    @current_user = nil
  end

  def require_user!
    return if signed_in?

    redirect_to new_session_path(return_to: request.fullpath), alert: "Войдите в аккаунт"
  end

  def safe_return_path
    return dashboard_path if params[:return_to].blank?

    uri = URI.parse(params[:return_to])
    uri.host.nil? ? uri.to_s : dashboard_path
  rescue URI::InvalidURIError
    dashboard_path
  end
end
