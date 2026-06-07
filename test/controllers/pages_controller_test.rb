require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "privacy page renders legal content and layout links" do
    get privacy_path

    assert_response :success
    assert_includes response.body, "Политика конфиденциальности"
    assert_includes response.body, "Яндекс Метрики"
    assert_includes response.body, "Google Analytics"
    assert_includes response.body, privacy_path
    assert_includes response.body, terms_path
  end

  test "terms page renders legal content and layout links" do
    get terms_path

    assert_response :success
    assert_includes response.body, "Пользовательское соглашение"
    assert_includes response.body, "Сервис предоставляется"
    assert_includes response.body, privacy_path
    assert_includes response.body, terms_path
  end

  test "layout renders cookie banner" do
    get privacy_path

    assert_response :success
    assert_includes response.body, "Мы используем cookies для работы сервиса, авторизации и аналитики"
    assert_includes response.body, "Понятно"
    assert_includes response.body, "Подробнее"
    assert_includes response.body, privacy_path
  end
end
