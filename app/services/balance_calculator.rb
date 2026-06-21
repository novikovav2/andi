class BalanceCalculator
  def initialize(event)
    @event = event
  end

  def call
    balances = participant_balances
    debtors = balances.select { |_id, amount| amount.negative? }
                      .map { |id, amount| [ participant(id), -amount ] }
    creditors = balances.select { |_id, amount| amount.positive? }
                        .map { |id, amount| [ participant(id), amount ] }
    settlements = []
    i = 0
    j = 0
    while i < debtors.length && j < creditors.length
      debtor, debt_amount = debtors[i]
      creditor, credit_amount = creditors[j]
      amount = [ debt_amount, credit_amount ].min
      settlements << {
        from: debtor,
        to: creditor,
        amount_cents: amount
      }

      debt_amount -= amount
      credit_amount -= amount
      debtors[i][1] = debt_amount
      creditors[j][1] = credit_amount

      i += 1 if debt_amount.zero?
      j += 1 if credit_amount.zero?
    end
    settlements
  end

  private
  attr_reader :event

  def participant_balances
    balances = event.participants.index_with(0)
    event.expenses.includes(:payer, expense_shares: :participant).find_each do |expense|
      shares = expense.expense_shares.select { |share| share.weight.positive? }
      next if shares.empty?

      split_amounts(expense, shares).each do |share, amount|
        balances[share.participant] -= amount
      end
      balances[expense.payer] += expense.amount_cents
    end
    balances.transform_keys(&:id)
  end

  def split_amounts(expense, shares)
    total_weight = shares.sum(&:weight)
    return [] unless total_weight.positive?

    weighted_amounts = shares.map do |share|
      exact_amount = BigDecimal(expense.amount_cents.to_s) * share.weight / total_weight
      [ share, exact_amount.floor, exact_amount.frac ]
    end

    remainder = expense.amount_cents - weighted_amounts.sum { |_share, amount, _fraction| amount }

    weighted_amounts
      .sort_by.with_index { |(_share, _amount, fraction), index| [ -fraction, index ] }
      .first(remainder)
      .each { |row| row[1] += 1 }

    weighted_amounts.map { |share, amount, _fraction| [ share, amount ] }
  end

  def participant(id)
    @participants_by_id ||= event.participants.index_by(&:id)
    @participants_by_id.fetch(id)
  end
end
