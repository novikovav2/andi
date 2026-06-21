require "test_helper"

class ExpenseShareTest < ActiveSupport::TestCase
  test "rejects negative weight" do
    event = Event.create!(
      title: "Weighted share validation trip",
      organizer_token: "weighted-share-validation-token"
    )
    participant = event.participants.create!(name: "Alice")
    expense = event.expenses.create!(
      title: "Taxi",
      amount_cents: 1000,
      payer: participant
    )

    expense_share = expense.expense_shares.build(participant:, weight: -1)

    assert_not expense_share.valid?
    assert_includes expense_share.errors.details[:weight],
                    { error: :greater_than_or_equal_to, value: -1, count: 0 }
  end
end
