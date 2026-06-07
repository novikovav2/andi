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

  test "picnic expenses page opens without authentication" do
    get picnic_expenses_path

    assert_response :success
    assert_select "h1", text: "Разделить расходы на пикнике без споров"
  end

  test "picnic expenses page has conversion content" do
    get picnic_expenses_path

    assert_response :success
    assert_includes response.body, "Создать мероприятие"
    assert_includes response.body, "FAQ"
    assert_includes response.body, "Без регистрации"
    assert_includes response.body, "Компания собралась на шашлыки"
  end

  test "party expenses page opens without authentication" do
    get party_expenses_path

    assert_response :success
    assert_select "h1", text: "Разделить расходы на вечеринке без споров"
  end

  test "party expenses page has conversion content" do
    get party_expenses_path

    assert_response :success
    assert_includes response.body, "Создать мероприятие"
    assert_includes response.body, "FAQ"
    assert_includes response.body, "Без регистрации"
    assert_includes response.body, "День рождения с друзьями"
  end
end
