class EventsController < ApplicationController
  before_action :set_event, only: [ :edit, :update, :destroy, :claim ]
  before_action :require_organizer!, only: [ :edit, :update, :destroy ]
  before_action :set_noindex, except: [ :new ]
  before_action :require_user!, only: [ :claim ]

  def new
    @event = Event.new
    @device_events = Event.owned_by(current_organizer_token).active
    @account_events = Event.none
    @device_only_events = Event.none

    if signed_in?
      @account_events = current_user.events.active.order(created_at: :desc)
      @device_only_events = @device_events.where.not(id: @account_events.select(:id))
    end

    set_meta_tags(
      title: "Разделить расходы без споров",
      description: "Анди помогает разделить расходы в поездках, на пикниках, вечеринках и других мероприятиях. Добавьте расходы и получите готовый список переводов."
    )
  end

  def create
    @event = Event.new(event_params)
    @event.organizer_token = current_organizer_token
    @event.user = current_user if signed_in?
    if @event.save
      Analytics.track(
        "event_created",
        eventable: @event
      )
      redirect_to event_share_path(@event.access_token)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @event = Event.find_by(access_token: params[:access_token])
    return render_not_found if @event.blank?

    @participants = @event.participants.order(:created_at)
    @expenses = @event.expenses
                      .includes(:payer, :participants, receipt_scan: { image_attachment: :blob })
                      .order(created_at: :desc)

    @balances = BalanceCalculator.new(@event).call

    @participant = Participant.new
    @expense = Expense.new
  end

  def edit
  end

  def update
    if @event.update(event_params)
      @participants = @event.participants.order(:created_at)

      respond_to do |format|
        format.html do
          redirect_to event_share_path(@event.access_token), notice: "Событие обновлено"
        end

        format.turbo_stream do
          flash.now[:notice] = "Событие обновлено"

          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash"),
            *event_refresh_streams(@event),
            turbo_stream.update("modal", "")
          ]
        end
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.settlements.destroy_all
    @event.expenses.destroy_all
    @event.participants.destroy_all
    @event.destroy!

    redirect_to root_path, notice: "Событие удалено"
  end

  def claim
    unless organizer?(@event)
      redirect_to event_share_path(@event.access_token), alert: "Только организатор может сохранить событие"
      return
    end

    @event.update!(user: current_user)

    redirect_to dashboard_path, notice: "Событие сохранено в аккаунт"
  end

  private
  def event_params
    params.require(:event).permit(:title)
  end

  def set_event
    @event = Event.find(params[:id])
  end

  def require_organizer!
    return if organizer?(@event)

    redirect_to event_share_path(@event.access_token),
                alert: "Только организатор может менять настройки события"
  end

  def set_noindex
    response.set_header(
      "X-Robots-Tag",
      "noindex, nofollow"
    )
  end
end
