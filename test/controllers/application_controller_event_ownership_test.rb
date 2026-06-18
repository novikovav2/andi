require "test_helper"

class ApplicationControllerEventOwnershipTest < ActiveSupport::TestCase
  test "signed in event user is treated as owner without organizer token" do
    user = create_user
    event = create_event(user:, organizer_token: "registered-owner-token")
    controller = ownership_controller(current_user: user, organizer_token: "other-device-token")

    assert controller.event_owner_or_guest_organizer?(event)
  end

  test "organizer token does not manage registered event for another user" do
    owner = create_user
    other_user = create_user
    event = create_event(user: owner, organizer_token: "registered-token")
    controller = ownership_controller(current_user: other_user, organizer_token: "registered-token")

    assert_not controller.event_owner_or_guest_organizer?(event)
  end

  test "guest event without user is managed by organizer token" do
    event = create_event(user: nil, organizer_token: "guest-token")
    controller = ownership_controller(current_user: nil, organizer_token: "guest-token")

    assert controller.event_owner_or_guest_organizer?(event)
  end

  private

  def ownership_controller(current_user:, organizer_token:)
    Class.new(ApplicationController) do
      attr_accessor :test_current_user, :test_organizer_token

      def current_user
        test_current_user
      end

      def current_organizer_token
        test_organizer_token
      end

      public :event_owner_or_guest_organizer?
    end.new.tap do |controller|
      controller.test_current_user = current_user
      controller.test_organizer_token = organizer_token
    end
  end

  def create_event(user:, organizer_token:)
    Event.create!(
      title: "Проверка прав",
      organizer_token:,
      user:
    )
  end

  def create_user
    User.create!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      plan: "pro"
    )
  end
end
