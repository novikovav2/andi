class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      sign_in(user)
      redirect_to safe_return_path, notice: "Вы вошли"
    else
      flash.now[:alert] = "Неверная почта или пароль"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out
    redirect_to root_path, notice: "Вы вышли"
  end
end
