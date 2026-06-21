class ExpensesController < ApplicationController
  before_action :set_event
  before_action :set_expense, only: [ :edit, :update, :destroy ]
  before_action :set_noindex

  def new
    @expense = Expense.new
    @participants = @event.participants.order(:created_at)
  end

  def create
    return unless ensure_valid_shares!

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
    previous_title = @expense.title
    previous_amount_cents = @expense.amount_cents
    previous_payer_id = @expense.payer_id
    previous_participant_ids = @expense.participant_ids.sort
    previous_share_weights = expense_share_weights(@expense)

    return unless ensure_valid_shares!

    @expense.update!(
      title: expense_params[:title],
      amount_cents: amount_to_cents(expense_params[:amount]),
      payer_id: expense_params[:payer_id]
    )

    sync_participants!

    flash.now[:notice] = "Трата обновлена"

    record_event_change!(
      expense_change_description(
        previous_title:,
        previous_amount_cents:,
        previous_payer_id:,
        previous_participant_ids:,
        previous_share_weights:
      )
    )

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
    params.require(:expense).permit(:title, :amount, :payer_id, :split_mode, participant_ids: [], share_weights: {})
  end

  def sync_participants!
    share_weights = @share_weights || build_share_weights

    @expense.expense_shares.where.not(participant_id: share_weights.keys).destroy_all

    share_weights.each do |participant_id, weight|
      expense_share = @expense.expense_shares.find_or_initialize_by(participant_id:)
      expense_share.weight = weight
      expense_share.save!
    end
  end

  def record_event_change!(description)
    @event.record_change!(description) if description.present?
  end

  def expense_change_description(previous_title:, previous_amount_cents:, previous_payer_id:, previous_participant_ids:, previous_share_weights:)
    current_participant_ids = @expense.expense_shares.reload.pluck(:participant_id).sort
    current_share_weights = expense_share_weights(@expense)

    if current_participant_ids != previous_participant_ids
      "Изменён состав участников для траты «#{@expense.title}»"
    elsif current_share_weights != previous_share_weights
      "Изменены доли для траты «#{@expense.title}»"
    elsif @expense.payer_id != previous_payer_id
      "Изменён плательщик для траты «#{@expense.title}»"
    elsif @expense.amount_cents != previous_amount_cents
      "Изменена сумма траты «#{@expense.title}»"
    elsif @expense.title != previous_title
      "Переименована трата «#{previous_title}» → «#{@expense.title}»"
    end
  end

  def amount_to_cents(amount)
    normalized = amount.to_s.strip.gsub(",", ".")

    return nil if normalized.blank?

    (BigDecimal(normalized) * 100).to_i
    rescue ArgumentError
      nil
  end

  def expense_share_weights(expense)
    expense.expense_shares.reload.each_with_object({}) do |share, weights|
      weights[share.participant_id] = share.weight.to_d
    end
  end

  def ensure_valid_shares!
    @share_weights = build_share_weights

    return true if !invalid_share_weight? && @share_weights.values.any?(&:positive?)

    message =
      if invalid_share_weight?
        "Введите неотрицательные количества"
      elsif quantity_split? && selected_participant_ids.any?
        "Укажите количество больше 0 хотя бы для одного участника"
      else
        "Выберите хотя бы одного участника"
      end

    @share_weights = nil

    @participants = @event.participants.order(:created_at)

    respond_to do |format|
      format.html do
        redirect_to event_share_path(@event.access_token),
                    alert: message
      end

      format.turbo_stream do
        flash.now[:alert] = message

        render turbo_stream: [
          turbo_stream.replace("flash", partial: "shared/flash")
        ], status: :unprocessable_entity
      end
    end

    false
  end

  def build_share_weights
    @invalid_share_weight = false

    participant_ids = selected_participant_ids
    valid_participant_ids = @event.participants.where(id: participant_ids).ids

    return valid_participant_ids.index_with { BigDecimal("1") } unless quantity_split?

    valid_participant_ids.each_with_object({}) do |participant_id, weights|
      weight = share_weight_for(participant_id)
      @invalid_share_weight = true if weight.nil? || weight.negative?
      weights[participant_id] = weight if weight.present? && weight.positive?
    end
  end

  def selected_participant_ids
    Array(expense_params[:participant_ids]).reject(&:blank?).map(&:to_i)
  end

  def quantity_split?
    expense_params[:split_mode] == "quantity"
  end

  def share_weight_for(participant_id)
    raw_weight = expense_params.fetch(:share_weights, {}).to_h[participant_id.to_s]
    weight_to_decimal(raw_weight.presence || "1")
  end

  def weight_to_decimal(weight)
    BigDecimal(weight.to_s.strip.gsub(",", "."))
  rescue ArgumentError
    nil
  end

  def invalid_share_weight?
    @invalid_share_weight
  end

  def set_noindex
    response.set_header(
      "X-Robots-Tag",
      "noindex, nofollow"
    )
  end
end
