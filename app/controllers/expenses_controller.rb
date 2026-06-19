class ExpensesController < ApplicationController
  before_action :set_event
  before_action :set_expense, only: [ :edit, :update, :destroy ]
  before_action :set_noindex

  def new
    @expense = Expense.new
    @participants = @event.participants.order(:created_at)
  end

  def create
    return unless ensure_participants_selected!

    @expense = @event.expenses.new(
      title: expense_params[:title],
      amount_cents: amount_to_cents(expense_params[:amount]),
      payer_id: expense_params[:payer_id]
    )

    if @expense.save
      Analytics.track(
        "expense_added",
        eventable: @expense,
        metadata: {
          amount_cents: @expense.amount_cents
        }
      )

      sync_participants!

      record_event_change!("Добавлена трата «#{@expense.title}»")

      @participants = @event.participants.order(:created_at)
      @balances = BalanceCalculator.new(@event).call

      respond_to do |format|
        format.html { redirect_to event_share_path(@event.access_token) }

        format.turbo_stream do
          flash.now[:notice] = "Трата добавлена"

          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash"),
            turbo_stream.remove("empty_expenses"),
            turbo_stream.prepend("expenses", partial: "expenses/expense", locals: { expense: @expense }),
            *event_refresh_streams(@event),
            turbo_stream.update("modal", "")
          ]
        end
      end
    else
      @participants = @event.participants.order(:created_at)

      respond_to do |format|
        format.html { redirect_to event_share_path(@event.access_token), alert: "Введите название и сумму" }

        format.turbo_stream do
          flash.now[:alert] = "Введите название и сумму"

          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash"),
            turbo_stream.replace("new_expense", partial: "expenses/form", locals: { event: @event, expense: @expense, participants: @participants })
          ], status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    @participants = @event.participants.order(:created_at)
  end

  def update
    return unless ensure_participants_selected!

    flash.now[:notice] = "Трата обновлена"
    @expense.update!(
      title: expense_params[:title],
      amount_cents: amount_to_cents(expense_params[:amount]),
      payer_id: expense_params[:payer_id]
    )

    sync_participants!

    record_event_change!("Изменена трата «#{@expense.title}»")

    @participants = @event.participants.order(:created_at)
    @balances = BalanceCalculator.new(@event).call

    respond_to do |format|
      format.html { redirect_to event_share_path(@event.access_token) }

      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          *event_refresh_streams(@event),
          turbo_stream.update("modal", "")
        ]
      end
    end
  end

  def destroy
    expense_title = @expense.title
    flash.now[:notice] = "Трата удалена"
    @expense.destroy!
    @event.mark_unconfirmed!
    record_event_change!("Удалена трата «#{expense_title}»")

    @balances = BalanceCalculator.new(@event).call

    respond_to do |format|
      format.html { redirect_to event_share_path(@event.access_token) }

      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash"),
          turbo_stream.remove(@expense),
          *event_refresh_streams(@event),
          turbo_stream.update("modal", "")
        ]
      end
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_expense
    @expense = @event.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(:title, :amount, :payer_id, participant_ids: [])
  end

  def sync_participants!
    participant_ids = Array(expense_params[:participant_ids]).reject(&:blank?).map(&:to_i)

    @expense.expense_shares.where.not(participant_id: participant_ids).destroy_all

    participant_ids.each do |participant_id|
      @expense.expense_shares.find_or_create_by!(participant_id:)
    end
  end

  def record_event_change!(description)
    @event.update!(
      status: "unconfirmed",
      last_change_description: description,
      last_change_at: Time.current
    )
  end

  def amount_to_cents(amount)
    normalized = amount.to_s.strip.gsub(",", ".")

    return nil if normalized.blank?

    (BigDecimal(normalized) * 100).to_i
    rescue ArgumentError
      nil
  end

  def ensure_participants_selected!
    participant_ids = Array(expense_params[:participant_ids]).reject(&:blank?)

    return true if participant_ids.any?

    @participants = @event.participants.order(:created_at)

    respond_to do |format|
      format.html do
        redirect_to event_share_path(@event.access_token),
                    alert: "Выберите хотя бы одного участника"
      end

      format.turbo_stream do
        flash.now[:alert] = "Выберите хотя бы одного участника"

        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash")
        ], status: :unprocessable_entity
      end
    end

    false
  end

  def set_noindex
    response.set_header(
      "X-Robots-Tag",
      "noindex, nofollow"
    )
  end
end
