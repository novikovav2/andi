class ReceiptScansController < ApplicationController
  AUTO_REFRESH_DURATION = 60.seconds

  before_action :set_event
  before_action :require_event_access!
  before_action :require_receipt_recognition_feature
  before_action :set_receipt_scan, only: [ :show, :confirm, :destroy ]
  before_action :require_receipt_scan_manager!, only: [ :destroy ]

  def new
    @receipt_scan = @event.receipt_scans.build
  end

  def create
    @receipt_scan = @event.receipt_scans.build(receipt_scan_params)

    if @receipt_scan.save
      @receipt_scan.update!(status: "pending", raw_result: nil, error: nil)
      ReceiptScanRecognitionJob.perform_later(@receipt_scan.id)
      redirect_to receipt_scan_path,
                  notice: "Чек загружен. Распознавание началось."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @items = @receipt_scan.raw_result&.dig("items") || []
    @participants = @event.participants.order(:name)
    @auto_refresh_receipt_scan = auto_refresh_receipt_scan?
  end

  def confirm
    items = params[:items] || {}
    payer = @event.participants.find_by(id: params[:payer_id])

    unless payer
      redirect_to receipt_scan_path,
                  alert: "Выберите плательщика из участников события"
      return
    end

    enabled_items = items.values.select { |item| item_value(item, :enabled) == "1" }

    if enabled_items.empty?
      redirect_to receipt_scan_path,
                  alert: "Не выбраны позиции для добавления"
      return
    end

    if enabled_items.any? { |item| selected_event_participant_ids(item).empty? }
      redirect_to receipt_scan_path,
                  alert: "Для каждой выбранной позиции отметьте участников"
      return
    end

    created_expenses = []

    Expense.transaction do
      enabled_items.each do |item|
        attributes = expense_attributes_for(item, payer:)
        next unless valid_expense_attributes?(attributes)

        expense = @event.expenses.create!(attributes.merge(receipt_scan: @receipt_scan))
        sync_receipt_expense_participants!(expense, selected_event_participant_ids(item))
        created_expenses << expense
      end
    end

    if created_expenses.empty?
      redirect_to receipt_scan_path,
                  alert: "Не выбраны позиции для добавления"
      return
    end

    @receipt_scan.update!(created_expenses_count: created_expenses.count)
    @event.record_change!(receipt_expenses_change_description(created_expenses.count))

    redirect_to event_share_path(@event.access_token), notice: "Позиции из чека добавлены"
  end

  def destroy
    if @receipt_scan.destroy
      redirect_to event_share_path(@event.access_token), notice: "Чек удалён"
    else
      redirect_to event_share_path(@event.access_token),
                  alert: "Чек уже связан с расходами, поэтому его нельзя удалить."
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def require_event_access!
    return if valid_event_access_token?
    return if organizer?(@event)
    return if signed_in? && @event.user == current_user

    render_not_found
  end

  def require_receipt_recognition_feature
    require_feature!(:receipt_recognition, event: @event)
  end

  def set_receipt_scan
    @receipt_scan = @event.receipt_scans.find(params[:id])
  end

  def require_receipt_scan_manager!
    return if event_owner_or_guest_organizer?(@event)

    redirect_to receipt_scan_path, alert: "Удалять чеки может только организатор"
  end

  def receipt_scan_params
    params.require(:receipt_scan).permit(:image)
  end

  def receipt_scan_path
    event_receipt_scan_path(@event, @receipt_scan, access_token: params[:access_token])
  end

  def valid_event_access_token?
    params[:access_token].present? &&
      @event.access_token.present? &&
      ActiveSupport::SecurityUtils.secure_compare(
        params[:access_token],
        @event.access_token
      )
  end

  def auto_refresh_receipt_scan?
    return false unless @receipt_scan.pending? || @receipt_scan.processing?
    return true unless @receipt_scan.created_at

    @receipt_scan.created_at > AUTO_REFRESH_DURATION.ago
  end

  def expense_attributes_for(item, payer:)
    attributes = {
      title: item_value(item, :title),
      amount_cents: amount_to_cents(item_value(item, :amount)),
      payer:
    }

    attributes[:category] = item_value(item, :category) if Expense.column_names.include?("category")

    attributes
  end

  def valid_expense_attributes?(attributes)
    attributes[:title].to_s.strip.present? && attributes[:amount_cents].to_i.positive?
  end

  def sync_receipt_expense_participants!(expense, participant_ids)
    @event.participants.where(id: participant_ids).find_each do |participant|
      expense.expense_shares.find_or_create_by!(participant:) do |expense_share|
        expense_share.weight = 1
      end
    end
  end

  def receipt_expenses_change_description(count)
    return "Добавлена трата из чека" if count == 1

    "Добавлено #{count} #{helpers.russian_plural(count, 'трата', 'траты', 'трат')} из чека"
  end

  def selected_participant_ids(item)
    Array(item_value(item, :participant_ids)).reject(&:blank?)
  end

  def selected_event_participant_ids(item)
    @event.participants.where(id: selected_participant_ids(item)).ids
  end

  def item_value(item, key)
    item[key] || item[key.to_s]
  end

  def amount_to_cents(amount)
    normalized = amount.to_s.strip.gsub(",", ".")

    return nil if normalized.blank?

    (BigDecimal(normalized) * 100).to_i
  rescue ArgumentError
    nil
  end
end
