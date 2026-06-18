require "test_helper"

class RailsInternalRoutesTest < ActionDispatch::IntegrationTest
  test "catch all does not handle active storage blob paths" do
    get "/rails/active_storage/blobs/some/path"

    assert_not_custom_not_found
  end

  test "catch all does not handle active storage representation paths" do
    get "/rails/active_storage/representations/some/path"

    assert_not_custom_not_found
  end

  test "catch all does not handle active storage disk paths" do
    get "/rails/active_storage/disk/some/path"

    assert_not_custom_not_found
  end

  test "catch all does not handle action mailbox paths" do
    post "/rails/action_mailbox/postmark/inbound_emails"

    assert_not_custom_not_found
  end

  test "custom not found still handles ordinary missing paths" do
    get "/some/missing/page"

    assert_response :not_found
    assert_includes response.body, "Такой страницы нет"
  end

  test "static server error page matches application error style" do
    body = Rails.root.join("public/500.html").read

    assert_includes body, "<main class=\"card\">"
    assert_includes body, "src=\"/icons/android-192.png\""
    assert_includes body, "😵 Что-то пошло не так"
    assert_includes body, "Во время обработки запроса произошла ошибка."
    assert_includes body, "Попробуйте обновить страницу через несколько минут."
    assert_includes body, "Если проблема повторяется, вернитесь на главную и попробуйте снова."
    assert_includes body, "<a href=\"/\">На главную</a>"
    assert_no_match(/stack trace|backtrace|exception|error id/i, body)
  end

  private

  def assert_not_custom_not_found
    assert_no_match "Такой страницы нет", response.body
  end
end
