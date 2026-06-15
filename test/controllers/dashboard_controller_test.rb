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

  test "shows active events in active block" do
    user = create_user(email: "active-dashboard@example.com")
    user.events.create!(
      title: "Active trip",
      organizer_token: "active-dashboard-token",
      status: "confirmed"
    )

    sign_in_as(user)

    get dashboard_path

    assert_response :success
    assert_select "section", text: /Активные мероприятия.*Active trip/m
  end

  test "shows settled events in archive only" do
    user = create_user(email: "archive-dashboard@example.com")
    user.events.create!(
      title: "Current picnic",
      organizer_token: "current-picnic-token",
      status: "confirmed"
    )
    user.events.create!(
      title: "Finished party",
      organizer_token: "finished-party-dashboard-token",
      status: "settled"
    )

    sign_in_as(user)

    get dashboard_path

    assert_response :success
    assert_select "section", text: /Активные мероприятия.*Current picnic/m
    assert_select "section", text: /Активные мероприятия.*Finished party/m, count: 0
    assert_select "details.dashboard-archive" do
      assert_select "summary", text: /Архив.*1/m
      assert_select ".dashboard-event-card-archived", text: /Finished party/
      assert_select ".dashboard-event-archived-badge", text: "Завершено"
    end
  end

  test "does not show archive when there are no settled events" do
    user = create_user(email: "no-archive-dashboard@example.com")
    user.events.create!(
      title: "Only active event",
      organizer_token: "only-active-dashboard-token",
      status: "draft"
    )

    sign_in_as(user)

    get dashboard_path

    assert_response :success
    assert_select "details.dashboard-archive", count: 0
    assert_includes response.body, "Only active event"
  end

  test "shows empty active state when user has only archived events" do
    user = create_user(email: "empty-active-dashboard@example.com")
    user.events.create!(
      title: "Old settled event",
      organizer_token: "old-settled-dashboard-token",
      status: "settled"
    )

    sign_in_as(user)

    get dashboard_path

    assert_response :success
    assert_includes response.body, "Активных мероприятий пока нет."
    assert_select "a[href=?]", root_path, text: "Создать мероприятие"
    assert_select "details.dashboard-archive", text: /Old settled event/
  end

  test "does not show other users events" do
    user = create_user(email: "owner-dashboard@example.com")
    other_user = create_user(email: "other-dashboard@example.com")
    user.events.create!(
      title: "Owner event",
      organizer_token: "owner-dashboard-token",
      status: "confirmed"
    )
    other_user.events.create!(
      title: "Other archived event",
      organizer_token: "other-archived-dashboard-token",
      status: "settled"
    )

    sign_in_as(user)

    get dashboard_path

    assert_response :success
    assert_includes response.body, "Owner event"
    assert_no_match "Other archived event", response.body
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

  private
  def sign_in_as(user)
    post session_path, params: {
      email: user.email,
      password: "password123"
    }
  end

  def create_user(email:)
    User.create!(
      email:,
      password: "password123",
      password_confirmation: "password123"
    )
  end
end
