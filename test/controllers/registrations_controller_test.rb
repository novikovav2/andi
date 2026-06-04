require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "creates user and redirects to dashboard" do
    assert_difference "User.count", 1 do
      post registration_path, params: {
        user: {
          email: "new@example.com",
          name: "New User",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to dashboard_path
  end

  test "does not create user with invalid params" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          email: "",
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
