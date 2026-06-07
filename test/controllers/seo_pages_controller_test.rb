require "test_helper"

class SeoPagesControllerTest < ActionDispatch::IntegrationTest
  test "trip expenses page opens without authentication" do
    get trip_expenses_path

    assert_response :success
    assert_select "h1", text: "Разделить расходы в поездке без споров"
  end

  test "trip expenses page has conversion content" do
    get trip_expenses_path

    assert_response :success
    assert_includes response.body, "Создать мероприятие"
    assert_includes response.body, "FAQ"
    assert_includes response.body, "Без регистрации"
  end
end
