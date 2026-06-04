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
    event.expenses.includes(:payer, :participants).find_each do |expense|
      participants = expense.participants.to_a
      next if participants.empty?
      share = expense.amount_cents / participants.size
      remainder = expense.amount_cents % participants.size
      participants.each_with_index do |participant, index|
        amount = share + (index < remainder ? 1 : 0)
        balances[participant] -= amount
      end
      balances[expense.payer] += expense.amount_cents
    end
    balances.transform_keys(&:id)
  end

  def participant(id)
    @participants_by_id ||= event.participants.index_by(&:id)
    @participants_by_id.fetch(id)
  end
end
