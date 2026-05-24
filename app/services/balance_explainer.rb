class BalanceExplainer
  def initialize(event, from_participant, to_participant)
    @event = event
    @from = from_participant
    @to = to_participant
  end

  def call
    {
      consumed_rows: consumed_rows,
      paid_rows: paid_rows,
      total_consumed_cents: total_consumed_cents,
      total_paid_cents: total_paid_cents,
      net_owed_cents: total_consumed_cents - total_paid_cents
    }
  end

  private

  def consumed_rows
    @consumed_rows ||= @event.expenses.includes(:payer, :participants).filter_map do |expense|
      participants = expense.participants.to_a
      next if participants.empty?
      next unless participants.include?(@from)

      share = expense.amount_cents / participants.size
      remainder = expense.amount_cents % participants.size
      index = participants.index(@from)

      amount = share + (index < remainder ? 1 : 0)

      {
        expense: expense,
        amount_cents: amount,
        participants_count: participants.size,
        participants: participants
      }
    end
  end

  def paid_rows
    @paid_rows ||= @event.expenses.includes(:participants).where(payer: @from).map do |expense|
      {
        expense: expense,
        amount_cents: expense.amount_cents,
        participants_count: expense.participants.count,
        participants: expense.participants.to_a
      }
    end
  end

  def total_consumed_cents
    consumed_rows.sum { |row| row[:amount_cents] }
  end

  def total_paid_cents
    paid_rows.sum { |row| row[:amount_cents] }
  end
end