require "test_helper"

class EventsAuthTest < ActionDispatch::IntegrationTest
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

  def create_user
    User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end
end
