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

  test "who owes whom page opens without authentication" do
    get who_owes_whom_path

    assert_response :success
    assert_select "h1", text: "Посчитать, кто кому должен"
  end

  test "who owes whom page has conversion content" do
    get who_owes_whom_path

    assert_response :success
    assert_includes response.body, "Создать мероприятие"
    assert_includes response.body, "FAQ"
    assert_includes response.body, "Без регистрации"
    assert_includes response.body, "После встречи остались чеки и вопросы"
  end

  test "business trip expenses page opens without authentication" do
    get business_trip_expenses_path

    assert_response :success
    assert_select "h1", text: "Удобный учёт расходов в командировке"
  end

  test "business trip expenses page has conversion content" do
    get business_trip_expenses_path

    assert_response :success
    assert_includes response.body, "Создать мероприятие"
    assert_includes response.body, "FAQ"
    assert_includes response.body, "Без регистрации"
    assert_includes response.body, "Командировка на несколько дней"
    assert_includes response.body, "Можно ли вести расходы несколько дней?"
  end

  test "business trip expenses page has seo meta tags" do
    get business_trip_expenses_path

    assert_response :success
    assert_select "title", text: /Учёт расходов в командировке — разделить траты с коллегами/
    assert_select "meta[name='description'][content=?]",
                  "Анди помогает учитывать расходы в командировке: билеты, отель, такси, питание и другие траты. Добавьте коллег, фиксируйте расходы по дням и получите понятный расчёт переводов."
    assert_select "link[rel='canonical'][href=?]", business_trip_expenses_url
  end
end
