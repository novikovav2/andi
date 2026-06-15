require "test_helper"

class EventsAuthTest < ActionDispatch::IntegrationTest
  test "home page opens without authentication" do
    get root_path

    assert_response :success
    assert_select "a.app-brand[href=?]", root_path
    assert_select "h1", text: "Разделить расходы без споров"
    assert_includes response.body, "Создать мероприятие"
    assert_includes response.body, "Для поездок, пикников и вечеринок"
    assert_includes response.body, "Почему удобно"
    assert_includes response.body, "Утро"
    assert_includes response.body, "День"
    assert_includes response.body, "Вечер"
    assert_includes response.body, "Анди всё посчитала"
  end

  test "guest sees events saved on current device" do
    post events_path, params: {
      event: {
        title: "Device picnic"
      }
    }

    get root_path

    assert_response :success
    assert_includes response.body, "Device picnic"
    assert_includes response.body, "События, созданные на этом устройстве"
    assert_includes response.body, "чтобы видеть мероприятия на всех устройствах"
  end

  test "signed in user sees active account events on home page" do
    user = create_user
    active_event = user.events.create!(
      title: "Account trip",
      organizer_token: "account-trip-token",
      status: "confirmed"
    )
    active_event.participants.create!(name: "Катя")

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_includes response.body, "Account trip"
    assert_includes response.body, "Мои активные мероприятия"
    assert_includes response.body, "Мероприятия, сохранённые в аккаунте"
  end

  test "signed in user also sees device event from current device" do
    post events_path, params: {
      event: {
        title: "Guest device trip"
      }
    }

    user = create_user
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_includes response.body, "Guest device trip"
    assert_includes response.body, "Мероприятия на этом устройстве"
    assert_includes response.body, "Эти мероприятия пока не привязаны к аккаунту"
    assert_no_match "Активных мероприятий пока нет.", response.body
  end

  test "signed in user does not see duplicate event already saved to account" do
    post events_path, params: {
      event: {
        title: "Shared event"
      }
    }

    event = Event.last
    user = create_user
    event.update!(user:)

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_equal 1, response.body.scan("Shared event").count
    assert_includes response.body, "Мои активные мероприятия"
    assert_no_match "Мероприятия на этом устройстве", response.body
  end

  test "signed in user does not see other users events on home page" do
    user = create_user
    other_user = create_user
    other_user.events.create!(
      title: "Other birthday",
      organizer_token: "other-birthday-token",
      status: "confirmed"
    )

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_no_match "Other birthday", response.body
  end

  test "signed in user does not see settled events in active home block" do
    user = create_user
    user.events.create!(
      title: "Finished party",
      organizer_token: "finished-party-token",
      status: "settled"
    )

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_no_match "Finished party", response.body
    assert_includes response.body, "Активных мероприятий пока нет."
  end

  test "signed in user does not see settled device events on home page" do
    post events_path, params: {
      event: {
        title: "Finished device picnic"
      }
    }
    Event.last.update!(status: "settled")

    user = create_user
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_no_match "Finished device picnic", response.body
    assert_no_match "Мероприятия на этом устройстве", response.body
    assert_includes response.body, "Активных мероприятий пока нет."
  end

  test "signed in user without active events sees empty home state" do
    user = create_user

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_includes response.body, "Активных мероприятий пока нет."
    assert_select "a[href='#create-event']", "Создать мероприятие"
  end

  test "guest creates event without user" do
    assert_difference "Event.count", 1 do
      post events_path, params: {
        event: {
          title: "Guest trip"
        }
      }
    end

    assert_nil Event.last.user
  end

  test "signed in user creates event with user" do
    user = create_user

    post session_path, params: {
      email: user.email,
      password: "password123"
    }

    assert_difference "Event.count", 1 do
      post events_path, params: {
        event: {
          title: "User trip"
        }
      }
    end

    assert_equal user, Event.last.user
  end

  test "organizer can claim guest event after registration" do
    post events_path, params: {
      event: {
        title: "Guest trip"
      }
    }

    event = Event.last
    assert_nil event.user

    post registration_path, params: {
      user: {
        email: "owner@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    patch claim_event_path(event)

    assert_redirected_to dashboard_path
    assert_equal User.last, event.reload.user
  end

  test "guest organizer sees account prompt and returns to event after registration" do
    post events_path, params: {
      event: {
        title: "Guest trip"
      }
    }

    event = Event.last

    get event_share_path(event.access_token)

    assert_response :success
    assert_match "Сохраните мероприятие в аккаунте", response.body
    assert_match new_registration_path(return_to: event_share_path(event.access_token)), response.body

    post registration_path, params: {
      return_to: event_share_path(event.access_token),
      user: {
        email: "return@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to event_share_path(event.access_token)

    get event_share_path(event.access_token)

    assert_response :success
    assert_no_match "Сохраните мероприятие в аккаунте", response.body
    assert_match "Сохранить", response.body
  end

  test "receipt recognition button is hidden for guest event" do
    event = Event.create!(
      title: "Guest trip",
      organizer_token: "guest-receipt-button-token"
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_no_match "Распознать чек", response.body
  end

  test "receipt recognition button is hidden for free event owner" do
    user = create_user(plan: "free")
    event = Event.create!(
      title: "Free trip",
      organizer_token: "free-receipt-button-token",
      user:
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_no_match "Распознать чек", response.body
  end

  test "receipt recognition button is visible for pro event owner" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Pro trip",
      organizer_token: "pro-receipt-button-token",
      user:
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_match "Распознать чек", response.body
  end

  test "unknown event token returns not found" do
    get event_share_path("wrong-token")

    assert_response :not_found
    assert_includes response.body, "Такой страницы нет"
    assert_includes response.body, "/icons/android-192.png"
  end

  test "unknown event token returns not found for settlement pages" do
    get event_settlements_path("wrong-token")

    assert_response :not_found
    assert_includes response.body, "Такой страницы нет"
  end

  test "unknown event token returns not found for balance explanation" do
    get balance_explanation_path("wrong-token", 1, 2)

    assert_response :not_found
    assert_includes response.body, "Такой страницы нет"
  end

  test "unknown route returns not found page" do
    get "/%D1%84/wrong-token"

    assert_response :not_found
    assert_includes response.body, "Такой страницы нет"
  end

  test "organizer can open event settings" do
    post events_path, params: {
      event: {
        title: "Guest trip"
      }
    }

    event = Event.last

    get edit_event_path(event)

    assert_response :success
    assert_match "Настройки события", response.body
  end

  test "non organizer can not open event settings" do
    event = Event.create!(
      title: "Someone else's trip",
      organizer_token: "other-token"
    )

    get edit_event_path(event)

    assert_redirected_to event_share_path(event.access_token)
  end

  test "non organizer cannot claim event" do
    user = create_user
    event = Event.create!(
      title: "Someone else's trip",
      organizer_token: "other-token"
    )

    post session_path, params: {
      email: user.email,
      password: "password123"
    }

    patch claim_event_path(event)

    assert_redirected_to event_share_path(event.access_token)
    assert_nil event.reload.user
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email: user.email,
      password: "password123"
    }
  end

  def create_user(plan: "free")
    User.create!(
      email: "user-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      plan:
    )
  end
end
