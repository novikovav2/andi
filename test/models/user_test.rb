require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with email and password" do
    user = User.new(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert user.valid?
  end

  test "normalizes email" do
    user = User.create!(
      email: " USER@Example.COM ",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_equal "user@example.com", user.email
  end

  test "requires unique email" do
    User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    duplicate = User.new(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:email, :taken)
  end

  test "requires password with at least 8 characters" do
    user = User.new(
      email: "user@example.com",
      password: "short",
      password_confirmation: "short"
    )

    assert_not user.valid?
    assert user.errors.of_kind?(:password, :too_short)
  end

  test "defaults to free plan" do
    user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert user.free?
  end
end
