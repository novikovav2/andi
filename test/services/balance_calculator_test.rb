require "test_helper"

class BalanceCalculatorTest < ActiveSupport::TestCase
  test "returns no settlements when there are no expenses" do
    event = create_event
    event.participants.create!(name: "Alice")
    event.participants.create!(name: "Bob")

    settlements = BalanceCalculator.new(event).call

    assert_empty settlements
  end

  test "splits one expense between two participants" do
    event = create_event
    alice = event.participants.create!(name: "Alice")
    bob = event.participants.create!(name: "Bob")

    expense = event.expenses.create!(
      title: "Taxi",
      amount_cents: 1000,
      payer: alice
    )
    expense.participants << [ alice, bob ]

    settlements = BalanceCalculator.new(event).call

    assert_equal 1, settlements.size
    assert_settlement settlements.first, from: bob, to: alice, amount_cents: 500
  end

  test "weights one one one match equal split" do
    event = create_event
    alice = event.participants.create!(name: "Alice")
    bob = event.participants.create!(name: "Bob")
    charlie = event.participants.create!(name: "Charlie")

    expense = event.expenses.create!(
      title: "Pizza",
      amount_cents: 1200,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice, weight: 1)
    expense.expense_shares.create!(participant: bob, weight: 1)
    expense.expense_shares.create!(participant: charlie, weight: 1)

    settlements = BalanceCalculator.new(event).call

    assert_equal 2, settlements.size
    assert_settlement settlements[0], from: bob, to: alice, amount_cents: 400
    assert_settlement settlements[1], from: charlie, to: alice, amount_cents: 400
  end

  test "splits expense by integer weights" do
    event = create_event
    ivan = event.participants.create!(name: "Ivan")
    petya = event.participants.create!(name: "Petya")
    sergey = event.participants.create!(name: "Sergey")

    expense = event.expenses.create!(
      title: "Beer",
      amount_cents: 100_000,
      payer: ivan
    )
    expense.expense_shares.create!(participant: ivan, weight: 1)
    expense.expense_shares.create!(participant: petya, weight: 1)
    expense.expense_shares.create!(participant: sergey, weight: 8)

    settlements = BalanceCalculator.new(event).call

    assert_equal 2, settlements.size
    assert_settlement settlements[0], from: petya, to: ivan, amount_cents: 10_000
    assert_settlement settlements[1], from: sergey, to: ivan, amount_cents: 80_000
  end

  test "splits expense by decimal weights" do
    event = create_event
    alice = event.participants.create!(name: "Alice")
    bob = event.participants.create!(name: "Bob")

    expense = event.expenses.create!(
      title: "Wine",
      amount_cents: 200_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice, weight: 0.5)
    expense.expense_shares.create!(participant: bob, weight: 1.5)

    settlements = BalanceCalculator.new(event).call

    assert_equal 1, settlements.size
    assert_settlement settlements.first, from: bob, to: alice, amount_cents: 150_000
  end

  test "distributes remainder cents deterministically" do
    event = create_event
    alice = event.participants.create!(name: "Alice")
    bob = event.participants.create!(name: "Bob")
    charlie = event.participants.create!(name: "Charlie")

    expense = event.expenses.create!(
      title: "Snacks",
      amount_cents: 1000,
      payer: alice
    )
    expense.participants << [ alice, bob, charlie ]

    settlements = BalanceCalculator.new(event).call

    assert_equal 2, settlements.size
    assert_settlement settlements[0], from: bob, to: alice, amount_cents: 333
    assert_settlement settlements[1], from: charlie, to: alice, amount_cents: 333
  end

  test "ignores participants who are not included in an expense" do
    event = create_event
    alice = event.participants.create!(name: "Alice")
    bob = event.participants.create!(name: "Bob")
    charlie = event.participants.create!(name: "Charlie")

    expense = event.expenses.create!(
      title: "Coffee",
      amount_cents: 900,
      payer: alice
    )
    expense.participants << [ alice, bob ]

    settlements = BalanceCalculator.new(event).call

    assert_equal 1, settlements.size
    assert_settlement settlements.first, from: bob, to: alice, amount_cents: 450
    assert_not settlements.any? { |settlement| settlement[:from] == charlie || settlement[:to] == charlie }
  end

  test "balances multiple payers" do
    event = create_event
    alice = event.participants.create!(name: "Alice")
    bob = event.participants.create!(name: "Bob")
    charlie = event.participants.create!(name: "Charlie")

    dinner = event.expenses.create!(
      title: "Dinner",
      amount_cents: 3000,
      payer: alice
    )
    dinner.participants << [ alice, bob, charlie ]

    taxi = event.expenses.create!(
      title: "Taxi",
      amount_cents: 1200,
      payer: bob
    )
    taxi.participants << [ alice, bob, charlie ]

    settlements = BalanceCalculator.new(event).call

    assert_equal 2, settlements.size
    assert_settlement settlements[0], from: bob, to: alice, amount_cents: 200
    assert_settlement settlements[1], from: charlie, to: alice, amount_cents: 1400
  end

  test "skips expenses without selected participants" do
    event = create_event
    alice = event.participants.create!(name: "Alice")
    event.participants.create!(name: "Bob")

    event.expenses.create!(
      title: "Broken expense",
      amount_cents: 1000,
      payer: alice
    )

    settlements = BalanceCalculator.new(event).call

    assert_empty settlements
  end

  test "skips expenses with zero total weight" do
    event = create_event
    alice = event.participants.create!(name: "Alice")
    bob = event.participants.create!(name: "Bob")

    expense = event.expenses.create!(
      title: "Broken weighted expense",
      amount_cents: 1000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice, weight: 0)
    expense.expense_shares.create!(participant: bob, weight: 0)

    settlements = BalanceCalculator.new(event).call

    assert_empty settlements
  end

  private

  def create_event
    Event.create!(
      title: "Trip",
      organizer_token: SecureRandom.urlsafe_base64(32)
    )
  end

  def assert_settlement(settlement, from:, to:, amount_cents:)
    assert_equal from, settlement[:from]
    assert_equal to, settlement[:to]
    assert_equal amount_cents, settlement[:amount_cents]
  end
end
