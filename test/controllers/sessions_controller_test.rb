require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "signs in with valid credentials" do
    post session_path, params: {
      email: "user@example.com",
      password: "password123"
    }

    assert_redirected_to dashboard_path
  end

  test "signs in with normalized email" do
    post session_path, params: {
      email: " USER@Example.COM ",
      password: "password123"
    }

    assert_redirected_to dashboard_path
  end

  test "rejects invalid credentials" do
    post session_path, params: {
      email: "user@example.com",
      password: "wrong-password"
    }

    assert_response :unprocessable_entity
  end

  test "signs out" do
    post session_path, params: {
      email: "user@example.com",
      password: "password123"
    }

    delete session_path

    assert_redirected_to root_path
  end
end
