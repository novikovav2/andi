require "test_helper"

class ReceiptScansControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs

    @user = User.create!(
      email: "receipt-owner@example.com",
      password: "password123",
      password_confirmation: "password123",
      plan: "pro"
    )
    @event = Event.create!(title: "Чек из кафе", status: "draft", organizer_token: "receipt-scan-test-token", user: @user)
    @payer = @event.participants.create!(name: "Катя")
    @friend = @event.participants.create!(name: "Сергей")

    post session_path, params: {
      email: @user.email,
      password: "password123"
    }
  end

  test "new shows upload form" do
    get new_event_receipt_scan_path(@event)

    assert_response :success
    assert_select "a.back-link[href=?]", event_share_path(@event.access_token), text: "← К событию"
    assert_select "h1", "Распознать чек"
    assert_select "input[type=file][name='receipt_scan[image]']"
    assert_select "input[type=submit][value='Загрузить чек']"
  end

  test "new redirects for free event owner" do
    free_user = User.create!(
      email: "free-receipt-owner@example.com",
      password: "password123",
      password_confirmation: "password123",
      plan: "free"
    )
    event = Event.create!(
      title: "Free чек",
      status: "draft",
      organizer_token: "free-receipt-scan-token",
      user: free_user
    )

    get new_event_receipt_scan_path(event, access_token: event.access_token)

    assert_redirected_to dashboard_path
    assert_equal "Эта возможность доступна на тарифе Pro", flash[:alert]
  end

  test "show returns not found without event access" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })
    delete session_path

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :not_found
  end

  test "create with image creates receipt scan, enqueues recognition job and redirects to show" do
    assert_enqueued_with(job: ReceiptScanRecognitionJob) do
      assert_difference -> { @event.receipt_scans.count }, 1 do
        post event_receipt_scans_path(@event), params: {
          receipt_scan: {
            image: fixture_file_upload("receipt.jpg", "image/jpeg")
          }
        }
      end
    end

    receipt_scan = @event.receipt_scans.last

    assert_redirected_to event_receipt_scan_path(@event, receipt_scan)
    assert_equal "Чек загружен. Распознавание началось.", flash[:notice]
    assert_predicate receipt_scan.reload, :pending?
    assert receipt_scan.image.attached?
  end

  test "show displays pending state" do
    receipt_scan = create_receipt_scan(status: "pending")

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :success
    assert_select "a.back-link[href=?]", event_share_path(@event.access_token), text: "← К событию"
    assert_select "div", text: /Чек распознаётся/
    assert_select "[data-controller='auto-refresh']"
    assert_select "[data-auto-refresh-delay-value='3000']"
    assert_select "[data-auto-refresh-max-duration-value='60000']"
    assert_select "[data-auto-refresh-started-at-value]"
    assert_select "p", "Страница обновится автоматически."
    assert_select "p.hidden", "Распознавание занимает больше времени, чем обычно."
    assert_select "input[type=submit][value='Добавить позиции в событие']", false
  end

  test "show displays processing state" do
    receipt_scan = create_receipt_scan(status: "processing")

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :success
    assert_select "div", text: /Чек распознаётся/
    assert_select "[data-controller='auto-refresh']"
    assert_select "[data-auto-refresh-delay-value='3000']"
    assert_select "[data-auto-refresh-max-duration-value='60000']"
    assert_select "[data-auto-refresh-started-at-value]"
    assert_select "p", "Страница обновится автоматически."
    assert_select "p.hidden", "Распознавание занимает больше времени, чем обычно."
    assert_select "input[type=submit][value='Добавить позиции в событие']", false
  end

  test "show stops auto refresh after one minute of waiting" do
    receipt_scan = create_receipt_scan(status: "processing")
    receipt_scan.update_column(:created_at, 61.seconds.ago)

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :success
    assert_select "div", text: /Чек распознаётся/
    assert_select "[data-controller='auto-refresh']", false
    assert_select "[data-auto-refresh-delay-value='3000']", false
    assert_select "p.hidden", "Страница обновится автоматически."
    assert_select "p", "Распознавание занимает больше времени, чем обычно."
  end

  test "show displays recognized test items" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" },
        { "title" => "Сыр", "amount" => "350.00", "category" => "food" }
      ]
    })

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :success
    assert_select "input[value='Хлеб']"
    assert_select "input[value='Сыр']"
    assert_select "p", text: "120 ₽"
    assert_select "button", "Все"
    assert_select "button", "Никто"
    assert_select "p", "Кому делить эту позицию"
    assert_select "input[name='items[0][participant_ids][]'][checked]"
    assert_select "input[name='items[0][category]']", false
    assert_select "input[type=submit][value='Добавить позиции в событие']"
    assert_select "[data-controller='auto-refresh']", false
  end

  test "show displays receipt image when attached" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :success
    assert_select "img.receipt-scan-image[alt='Фото чека']"
    assert_no_match "Фото чека удалено, но результат распознавания сохранён.", response.body
  end

  test "receipt scan blob path is served by active storage" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })

    get rails_blob_path(receipt_scan.image, disposition: "inline")

    assert_response :redirect

    follow_redirect!

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "show displays image placeholder when image was purged" do
    receipt_scan = create_receipt_scan(
      status: "ready",
      image_purged_at: Time.current,
      raw_result: {
        "items" => [
          { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
        ]
      }
    )

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :success
    assert_includes response.body, "Фото чека удалено, но результат распознавания сохранён."
    assert_select "img.receipt-scan-image", false
  end

  test "show displays payer radio chips when event has participants" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :success
    assert_select "p", "Кто оплатил чек?"
    assert_select "select[name=payer_id]", false
    assert_select "input[type=radio][name=payer_id][value=?][checked]", @payer.id.to_s
    assert_select "input[type=radio][name=payer_id][value=?]", @friend.id.to_s
  end

  test "show displays failed status error" do
    receipt_scan = create_receipt_scan(status: "failed", error: "Фото слишком размыто")

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :success
    assert_select ".text-red-700", text: /Фото слишком размыто/
    assert_select "a", "Загрузить другой чек"
    assert_select "form[action=?]", event_receipt_scan_path(@event, receipt_scan) do
      assert_select "button", "Удалить чек"
    end
    assert_select "[data-controller='auto-refresh']", false
  end

  test "destroy removes receipt scan and keeps created expenses" do
    receipt_scan = create_receipt_scan(
      status: "failed",
      error: "Фото слишком размыто",
      raw_result: { "items" => [ { "title" => "Кофе", "amount" => "120.00" } ] },
      recognized_items_count: 1,
      created_expenses_count: 1
    )
    expense = @event.expenses.create!(
      title: "Кофе",
      amount_cents: 12_000,
      payer: @payer
    )

    assert_difference "ReceiptScan.count", -1 do
      assert_no_difference "Expense.count" do
        delete event_receipt_scan_path(@event, receipt_scan)
      end
    end

    assert_redirected_to event_share_path(@event.access_token)
    assert_equal "Чек удалён", flash[:notice]
    assert_not ReceiptScan.exists?(receipt_scan.id)
    assert @event.expenses.exists?(expense.id)
  end

  test "registered event owner can delete receipt scan without organizer token" do
    receipt_scan = create_receipt_scan(status: "failed", error: "Фото слишком размыто")
    delete session_path

    post session_path, params: {
      email: @user.email,
      password: "password123"
    }

    assert_difference "ReceiptScan.count", -1 do
      delete event_receipt_scan_path(@event, receipt_scan)
    end

    assert_redirected_to event_share_path(@event.access_token)
    assert_equal "Чек удалён", flash[:notice]
  end

  test "organizer token does not show receipt delete button for registered event non owner" do
    post events_path, params: {
      event: {
        title: "Protected receipt trip"
      }
    }

    event = Event.last
    event.update!(user: @user)
    receipt_scan = event.receipt_scans.build(status: "failed", error: "Фото слишком размыто")
    receipt_scan.image.attach(
      io: Rails.root.join("test/fixtures/files/receipt.jpg").open,
      filename: "receipt.jpg",
      content_type: "image/jpeg"
    )
    receipt_scan.save!

    delete session_path
    get event_receipt_scan_path(event, receipt_scan)

    assert_response :success
    assert_no_match "Удалить чек", response.body
  end

  test "organizer token does not delete receipt scan for registered event non owner" do
    post events_path, params: {
      event: {
        title: "Protected receipt destroy trip"
      }
    }

    event = Event.last
    event.update!(user: @user)
    receipt_scan = event.receipt_scans.build(status: "failed", error: "Фото слишком размыто")
    receipt_scan.image.attach(
      io: Rails.root.join("test/fixtures/files/receipt.jpg").open,
      filename: "receipt.jpg",
      content_type: "image/jpeg"
    )
    receipt_scan.save!

    delete session_path

    assert_no_difference "ReceiptScan.count" do
      delete event_receipt_scan_path(event, receipt_scan)
    end

    assert_redirected_to event_receipt_scan_path(event, receipt_scan)
    assert_equal "Удалять чеки может только организатор", flash[:alert]
  end

  test "destroy removes receipt from event but keeps expenses visible" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })
    @event.expenses.create!(
      title: "Хлеб",
      amount_cents: 12_000,
      payer: @payer
    )

    delete event_receipt_scan_path(@event, receipt_scan)
    get event_share_path(@event.access_token)

    assert_response :success
    assert_no_match "Открыть чек", response.body
    assert_includes response.body, "Хлеб"
  end

  test "destroy does not remove receipt scan linked to expenses" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })
    @event.expenses.create!(
      title: "Хлеб",
      amount_cents: 12_000,
      payer: @payer,
      receipt_scan:
    )

    assert_no_difference "ReceiptScan.count" do
      delete event_receipt_scan_path(@event, receipt_scan)
    end

    assert_redirected_to event_share_path(@event.access_token)
    assert_equal "Чек уже связан с расходами, поэтому его нельзя удалить.", flash[:alert]
    assert ReceiptScan.exists?(receipt_scan.id)
  end

  test "show hides delete button when receipt scan is linked to expenses" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })
    @event.expenses.create!(
      title: "Хлеб",
      amount_cents: 12_000,
      payer: @payer,
      receipt_scan:
    )

    get event_receipt_scan_path(@event, receipt_scan)

    assert_response :success
    assert_select "form[action=?]", event_receipt_scan_path(@event, receipt_scan), count: 0
    assert_no_match "Удалить чек", response.body
  end

  test "show hides submit when event has no participants" do
    empty_event = Event.create!(title: "Пустое событие", status: "draft", organizer_token: "empty-receipt-token")
    empty_event.update!(user: @user)
    receipt_scan = empty_event.receipt_scans.build(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })
    receipt_scan.image.attach(
      io: Rails.root.join("test/fixtures/files/receipt.jpg").open,
      filename: "receipt.jpg",
      content_type: "image/jpeg"
    )
    receipt_scan.save!

    get event_receipt_scan_path(empty_event, receipt_scan)

    assert_response :success
    assert_select "div", text: /Сначала добавьте участников события/
    assert_select "input[type=submit][value='Добавить позиции в событие']", false
  end

  test "confirm creates expenses for selected enabled items" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" },
        { "title" => "Сыр", "amount" => "350.00", "category" => "food" }
      ]
    })

    assert_difference "Expense.count", 2 do
      post confirm_event_receipt_scan_path(@event, receipt_scan), params: {
        payer_id: @payer.id,
        items: {
          "0" => {
            enabled: "1",
            title: "Хлеб",
            amount: "120.00",
            category: "food",
            participant_ids: [ @payer.id, @friend.id ]
          },
          "1" => {
            enabled: "1",
            title: "Сыр",
            amount: "350.00",
            category: "food",
            participant_ids: [ @payer.id, @friend.id ]
          }
        }
      }
    end

    assert_redirected_to event_share_path(@event.access_token)

    expense = @event.expenses.find_by!(title: "Хлеб")
    assert_equal @payer, expense.payer
    assert_equal 12_000, expense.amount_cents
    assert_equal receipt_scan, expense.receipt_scan
    assert_equal @event.participants.pluck(:id).sort, expense.participant_ids.sort
    assert_equal 2, receipt_scan.reload.created_expenses_count
    assert_equal "Добавлено 2 траты из чека", @event.reload.last_change_description
  end

  test "confirm creates expense shares only for selected participants" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })

    assert_difference "Expense.count", 1 do
      post confirm_event_receipt_scan_path(@event, receipt_scan), params: {
        payer_id: @payer.id,
        items: {
          "0" => {
            enabled: "1",
            title: "Хлеб",
            amount: "120.00",
            category: "food",
            participant_ids: [ @friend.id ]
          }
        }
      }
    end

    expense = @event.expenses.find_by!(title: "Хлеб")
    assert_equal [ @friend.id ], expense.participant_ids
    assert_equal receipt_scan, expense.receipt_scan
    assert_equal 1, receipt_scan.reload.created_expenses_count
    assert_equal "Добавлена трата из чека", @event.reload.last_change_description
  end

  test "confirm does not create expenses without payer" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })

    assert_no_difference "Expense.count" do
      post confirm_event_receipt_scan_path(@event, receipt_scan), params: {
        items: {
          "0" => {
            enabled: "1",
            title: "Хлеб",
            amount: "120.00",
            category: "food",
            participant_ids: [ @payer.id, @friend.id ]
          }
        }
      }
    end

    assert_redirected_to event_receipt_scan_path(@event, receipt_scan)
    assert_equal "Выберите плательщика из участников события", flash[:alert]
  end

  test "confirm does not create expenses with payer from another event" do
    other_event = Event.create!(title: "Другое событие", status: "draft", organizer_token: "other-receipt-token")
    other_payer = other_event.participants.create!(name: "Чужой участник")
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })

    assert_no_difference "Expense.count" do
      post confirm_event_receipt_scan_path(@event, receipt_scan), params: {
        payer_id: other_payer.id,
        items: {
          "0" => {
            enabled: "1",
            title: "Хлеб",
            amount: "120.00",
            category: "food",
            participant_ids: [ @payer.id, @friend.id ]
          }
        }
      }
    end

    assert_redirected_to event_receipt_scan_path(@event, receipt_scan)
    assert_equal "Выберите плательщика из участников события", flash[:alert]
  end

  test "confirm ignores disabled items" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" },
        { "title" => "Сыр", "amount" => "350.00", "category" => "food" }
      ]
    })

    assert_difference "Expense.count", 1 do
      post confirm_event_receipt_scan_path(@event, receipt_scan), params: {
        payer_id: @payer.id,
        items: {
          "0" => {
            enabled: "1",
            title: "Хлеб",
            amount: "120.00",
            category: "food",
            participant_ids: [ @payer.id ]
          },
          "1" => {
            enabled: "0",
            title: "Сыр",
            amount: "350.00",
            category: "food"
          }
        }
      }
    end

    assert @event.expenses.exists?(title: "Хлеб")
    assert_not @event.expenses.exists?(title: "Сыр")
  end

  test "confirm does not create expenses when enabled item has no participants" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "Хлеб", "amount" => "120.00", "category" => "food" }
      ]
    })

    assert_no_difference "Expense.count" do
      post confirm_event_receipt_scan_path(@event, receipt_scan), params: {
        payer_id: @payer.id,
        items: {
          "0" => {
            enabled: "1",
            title: "Хлеб",
            amount: "120.00",
            category: "food",
            participant_ids: []
          }
        }
      }
    end

    assert_redirected_to event_receipt_scan_path(@event, receipt_scan)
    assert_equal "Для каждой выбранной позиции отметьте участников", flash[:alert]
  end

  test "confirm ignores items with blank title or invalid amount" do
    receipt_scan = create_receipt_scan(status: "ready", raw_result: {
      "items" => [
        { "title" => "", "amount" => "120.00", "category" => "food" },
        { "title" => "Сыр", "amount" => "не сумма", "category" => "food" },
        { "title" => "Сок", "amount" => "0", "category" => "food" }
      ]
    })

    assert_no_difference "Expense.count" do
      post confirm_event_receipt_scan_path(@event, receipt_scan), params: {
        payer_id: @payer.id,
        items: {
          "0" => {
            enabled: "1",
            title: "",
            amount: "120.00",
            category: "food",
            participant_ids: [ @payer.id, @friend.id ]
          },
          "1" => {
            enabled: "1",
            title: "Сыр",
            amount: "не сумма",
            category: "food",
            participant_ids: [ @payer.id, @friend.id ]
          },
          "2" => {
            enabled: "1",
            title: "Сок",
            amount: "0",
            category: "food",
            participant_ids: [ @payer.id, @friend.id ]
          }
        }
      }
    end

    assert_redirected_to event_receipt_scan_path(@event, receipt_scan)
    assert_equal "Не выбраны позиции для добавления", flash[:alert]
  end

  private

  def create_receipt_scan(attributes = {})
    receipt_scan = @event.receipt_scans.build(attributes.reverse_merge(status: "pending"))
    receipt_scan.image.attach(
      io: Rails.root.join("test/fixtures/files/receipt.jpg").open,
      filename: "receipt.jpg",
      content_type: "image/jpeg"
    )
    receipt_scan.save!
    receipt_scan
  end
end
