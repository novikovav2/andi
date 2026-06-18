class ParticipantsController < ApplicationController
  before_action :set_event
  before_action :set_participant, only: [ :edit, :update, :destroy ]
  before_action :set_noindex

  def create
    participant = @event.participants.create!(participant_params)

    @participants = @event.participants.order(:created_at)
    @participant = Participant.new
    @balances = BalanceCalculator.new(@event).call

    Analytics.track(
      "participant_added",
      eventable: participant
    )

    respond_to do |format|
      format.html do
        redirect_to event_share_path(@event.access_token),
                    notice: "Участник добавлен"
      end

      format.turbo_stream do
        flash.now[:notice] = "Участник добавлен"

        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          *event_refresh_streams(@event),
          turbo_stream.update("modal", "")
        ]
      end
    end
  end

  def edit
    @expenses = @event.expenses.includes(:participants).order(created_at: :desc)
  end

  def update
    old_expense_ids = @participant.expense_shares.pluck(:expense_id).sort
    @participant.update!(participant_params)

    new_expense_ids = Array(params.dig(:participant, :expense_ids))
                        .reject(&:blank?)
                        .map(&:to_i)
                        .sort

    changed_participation = old_expense_ids != new_expense_ids
    @event.expenses.find_each do |expense|
      share = expense.expense_shares.find_by(participant: @participant)
      if new_expense_ids.include?(expense.id)
        expense.expense_shares.find_or_create_by!(participant: @participant)
      else
        share&.destroy!
      end
    end

    @event.mark_unconfirmed! if changed_participation

    @participants = @event.participants.order(:created_at)
    @participant_form = Participant.new
    @balances = BalanceCalculator.new(@event).call
    @expenses = @event.expenses.includes(:payer, :participants).order(created_at: :desc)

    respond_to do |format|
      format.html { redirect_to event_share_path(@event.access_token) }

      format.turbo_stream do
        flash.now[:notice] = "Участник обновлён"

        streams = [
          turbo_stream.replace("flash", partial: "shared/flash"),
          *event_refresh_streams(@event),
          turbo_stream.update("modal", "")
        ]

        @expenses.each do |expense|
          streams << turbo_stream.replace(
            expense,
            partial: "expenses/expense",
            locals: { expense: expense }
          )
        end

        streams << turbo_stream.update("modal", "")

        render turbo_stream: streams
      end
    end
  end

  def destroy
    unless event_owner_or_guest_organizer?(@event)
      respond_to do |format|
        format.html do
          redirect_to event_share_path(@event.access_token),
                      alert: "Только организатор может удалять участников"
        end

        format.turbo_stream do
          flash.now[:alert] = "Только организатор может удалять участников"

          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash")
          ], status: :forbidden
        end
      end

      return
    end

    if @participant.paid_expenses.exists?
      respond_to do |format|
        format.html do
          redirect_to event_share_path(@event.access_token), alert: "Нельзя удалить участника, который оплачивал траты"
        end

        format.turbo_stream do
          flash.now[:alert] = "Нельзя удалить участника, который оплачивал траты"

          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash"),
            turbo_stream.replace("settlements_link", partial: "events/settlements_link", locals: { event: @event })
          ], status: :unprocessable_entity
        end
      end

      return
    end

    @event.settlements.destroy_all
    @event.update!(status: "unconfirmed", locked_at: nil) if @event.expenses.any?

    @participant.destroy!

    @event.mark_unconfirmed!

    @participants = @event.participants.order(:created_at)
    @participant_form = Participant.new
    @balances = BalanceCalculator.new(@event).call
    @expenses = @event.expenses.includes(:payer, :participants).order(created_at: :desc)

    respond_to do |format|
      format.html do
        redirect_to event_share_path(@event.access_token), notice: "Участник удалён"
      end

      format.turbo_stream do
        flash.now[:notice] = "Участник удалён"

        streams = [
          turbo_stream.replace("flash", partial: "shared/flash"),
          *event_refresh_streams(@event),
          turbo_stream.update("modal", "")
        ]

        @expenses.each do |expense|
          streams << turbo_stream.replace(
            expense,
            partial: "expenses/expense",
            locals: { expense: expense }
          )
        end

        streams << turbo_stream.update("modal", "")

        render turbo_stream: streams
      end
    end
  end

  def sheet
    @participants = @event.participants.order(:created_at)
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_participant
    @participant = @event.participants.find(params[:id])
  end

  def participant_params
    params.require(:participant).permit(:name)
  end

  def set_noindex
    response.set_header(
      "X-Robots-Tag",
      "noindex, nofollow"
    )
  end
end
