require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects guest to sign in" do
    get dashboard_path

    assert_redirected_to new_session_path(return_to: dashboard_path)
  end

  test "allows signed in user" do
    user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post session_path, params: {
      email: user.email,
      password: "password123"
    }

    get dashboard_path

    assert_response :success
  end

  test "shows participants count and total expenses without multiplying joins" do
    user = User.create!(
      email: "dashboard@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    event = user.events.create!(
      title: "Party",
      organizer_token: "organizer-token"
    )

    alice = event.participants.create!(name: "Alice")
    bob = event.participants.create!(name: "Bob")
    charlie = event.participants.create!(name: "Charlie")
    david = event.participants.create!(name: "David")

    expense = event.expenses.create!(
      title: "Snacks",
      amount_cents: 10_000,
      payer: alice
    )
    expense.participants << [ alice, bob, charlie, david ]

    post session_path, params: {
      email: user.email,
      password: "password123"
    }

    get dashboard_path

    assert_response :success
    assert_match "4 участников", response.body
    assert_match "100 ₽ трат", response.body
    assert_no_match "400 ₽ трат", response.body
  end

  test "shows event date in Russian locale" do
    user = User.create!(
      email: "locale@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    travel_to Time.zone.local(2026, 6, 5, 12, 0, 0) do
      user.events.create!(
        title: "Summer trip",
        organizer_token: "locale-token"
      )
    end

    post session_path, params: {
      email: user.email,
      password: "password123"
    }

    get dashboard_path

    assert_response :success
    assert_match "5 июня 2026", response.body
    assert_no_match "June", response.body
  end
end
