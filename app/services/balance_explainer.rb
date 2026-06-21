class BalanceExplainer
  def initialize(event, from_participant, to_participant)
    @event = event
    @from = from_participant
    @to = to_participant
  end

  def call
    {
      raw_debts: raw_debts,
      consumed_rows: consumed_rows,
      paid_rows: paid_rows,
      total_consumed_cents: total_consumed_cents,
      total_paid_cents: total_paid_cents,
      net_owed_cents: total_consumed_cents - total_paid_cents
    }
  end

  private

  def raw_debts
    @raw_debts ||= @event.expenses.includes(:payer, expense_shares: :participant).flat_map do |expense|
      shares = positive_shares(expense)
      split_amounts(expense, shares).filter_map do |share, amount_cents|
        next if share.participant == expense.payer
        next unless amount_cents.positive?

        {
          from: share.participant,
          to: expense.payer,
          amount_cents: amount_cents,
          expense: expense
        }
      end
    end
  end

  def consumed_rows
    @consumed_rows ||= @event.expenses.includes(:payer, expense_shares: :participant).filter_map do |expense|
      shares = positive_shares(expense)
      next if shares.empty?

      participant_share = shares.find { |share| share.participant == @from }
      next unless participant_share

      amount = split_amounts(expense, shares).fetch(participant_share)

      {
        expense: expense,
        amount_cents: amount,
        participants_count: shares.size,
        participants: shares.map(&:participant)
      }
    end
  end

  def paid_rows
    @paid_rows ||= @event.expenses.includes(expense_shares: :participant).where(payer: @from).map do |expense|
      shares = positive_shares(expense)
      {
        expense: expense,
        amount_cents: expense.amount_cents,
        participants_count: shares.size,
        participants: shares.map(&:participant)
      }
    end
  end

  def positive_shares(expense)
    expense.expense_shares.select { |share| share.weight.positive? }
  end

  def split_amounts(expense, shares)
    total_weight = shares.sum(&:weight)
    return {} unless total_weight.positive?

    weighted_amounts = shares.map do |share|
      exact_amount = BigDecimal(expense.amount_cents.to_s) * share.weight / total_weight
      [ share, exact_amount.floor, exact_amount.frac ]
    end

    remainder = expense.amount_cents - weighted_amounts.sum { |_share, amount, _fraction| amount }

    weighted_amounts
      .sort_by.with_index { |(_share, _amount, fraction), index| [ -fraction, index ] }
      .first(remainder)
      .each { |row| row[1] += 1 }

    weighted_amounts.to_h { |share, amount, _fraction| [ share, amount ] }
  end

  def total_consumed_cents
    consumed_rows.sum { |row| row[:amount_cents] }
  end

  def total_paid_cents
    paid_rows.sum { |row| row[:amount_cents] }
  end
end
