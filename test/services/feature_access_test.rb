require "test_helper"

class FeatureAccessTest < ActiveSupport::TestCase
  test "guest can not use paid features" do
    access = FeatureAccess.new(nil)

    assert_not access.receipt_recognition?
    assert_not access.event_photos?
    assert_not access.event_history?
  end

  test "free user can use event history but not paid features" do
    user = create_user(plan: "free")
    access = FeatureAccess.new(user)

    assert access.event_history?
    assert_not access.receipt_recognition?
    assert_not access.event_photos?
  end

  test "pro user can use paid features" do
    user = create_user(plan: "pro")
    access = FeatureAccess.new(user)

    assert access.event_history?
    assert access.receipt_recognition?
    assert access.event_photos?
    assert access.enabled?(:receipt_recognition)
    assert access.enabled?(:event_photos)
  end

  test "unknown features are disabled" do
    user = create_user(plan: "pro")
    access = FeatureAccess.new(user)

    assert_not access.enabled?(:unknown_feature)
  end

  test "event access depends on event owner plan" do
    owner = create_user(plan: "pro")
    event = owner.events.create!(
      title: "Party",
      organizer_token: "owner-token"
    )

    access = FeatureAccess.for_event(event)

    assert access.receipt_recognition?
    assert access.event_photos?
  end

  test "guest event has no paid feature access" do
    event = Event.create!(
      title: "Guest party",
      organizer_token: "guest-token"
    )

    access = FeatureAccess.for_event(event)

    assert_not access.receipt_recognition?
    assert_not access.event_photos?
  end

  private

  def create_user(plan:)
    User.create!(
      email: "#{plan}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      plan: plan
    )
  end
end
