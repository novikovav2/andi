class EventsController < ApplicationController
  before_action :set_event, only: [:edit, :update, :destroy]
  before_action :require_organizer!, only: [:edit, :update, :destroy]
  def new
    @event = Event.new
    @my_events = Event.owned_by(current_organizer_token)
  end

  def create
    @event = Event.new(event_params)
    @event.organizer_token = current_organizer_token
    if @event.save
      redirect_to event_share_path(@event.access_token)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @event = Event.find_by!(access_token: params[:access_token])

    @participants = @event.participants.order(:created_at)
    @expenses = @event.expenses.includes(:payer, :participants).order(created_at: :desc)

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
end
