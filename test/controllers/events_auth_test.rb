require "test_helper"

class EventsAuthTest < ActionDispatch::IntegrationTest
  test "home page opens without authentication" do
    get root_path

    assert_response :success
    assert_select "a.app-brand[href=?]", root_path
    assert_select "h1", text: "Разделить расходы без споров"
    assert_includes response.body, "Создать мероприятие"
    assert_includes response.body, "Для поездок, пикников и вечеринок"
    assert_includes response.body, "Почему удобно"
    assert_includes response.body, "Утро"
    assert_includes response.body, "День"
    assert_includes response.body, "Вечер"
    assert_includes response.body, "Анди всё посчитала"
    assert_includes response.body, "Командировка на несколько дней"
    assert_select "a[href=?]", business_trip_expenses_path, text: "Подробнее про командировки →"
  end

  test "guest sees events saved on current device" do
    post events_path, params: {
      event: {
        title: "Device picnic"
      }
    }

    get root_path

    assert_response :success
    assert_includes response.body, "Device picnic"
    assert_includes response.body, "События, созданные на этом устройстве"
    assert_includes response.body, "чтобы видеть мероприятия на всех устройствах"
  end

  test "signed in user sees active account events on home page" do
    user = create_user
    active_event = user.events.create!(
      title: "Account trip",
      organizer_token: "account-trip-token",
      status: "confirmed"
    )
    active_event.participants.create!(name: "Катя")

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_includes response.body, "Account trip"
    assert_includes response.body, "Мои активные мероприятия"
    assert_includes response.body, "Мероприятия, сохранённые в аккаунте"
  end

  test "signed in user also sees device event from current device" do
    post events_path, params: {
      event: {
        title: "Guest device trip"
      }
    }

    user = create_user
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_includes response.body, "Guest device trip"
    assert_includes response.body, "Мероприятия на этом устройстве"
    assert_includes response.body, "Эти мероприятия пока не привязаны к аккаунту"
    assert_no_match "Активных мероприятий пока нет.", response.body
  end

  test "signed in user does not see duplicate event already saved to account" do
    post events_path, params: {
      event: {
        title: "Shared event"
      }
    }

    event = Event.last
    user = create_user
    event.update!(user:)

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_equal 1, response.body.scan("Shared event").count
    assert_includes response.body, "Мои активные мероприятия"
    assert_no_match "Мероприятия на этом устройстве", response.body
  end

  test "signed in user does not see other users events on home page" do
    user = create_user
    other_user = create_user
    other_user.events.create!(
      title: "Other birthday",
      organizer_token: "other-birthday-token",
      status: "confirmed"
    )

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_no_match "Other birthday", response.body
  end

  test "signed in user does not see settled events in active home block" do
    user = create_user
    user.events.create!(
      title: "Finished party",
      organizer_token: "finished-party-token",
      status: "settled"
    )

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_no_match "Finished party", response.body
    assert_includes response.body, "Активных мероприятий пока нет."
  end

  test "signed in user does not see settled device events on home page" do
    post events_path, params: {
      event: {
        title: "Finished device picnic"
      }
    }
    Event.last.update!(status: "settled")

    user = create_user
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_no_match "Finished device picnic", response.body
    assert_no_match "Мероприятия на этом устройстве", response.body
    assert_includes response.body, "Активных мероприятий пока нет."
  end

  test "signed in user without active events sees empty home state" do
    user = create_user

    sign_in_as(user)

    get root_path

    assert_response :success
    assert_includes response.body, "Активных мероприятий пока нет."
    assert_select "a[href='#create-event']", "Создать мероприятие"
  end

  test "guest creates event without user" do
    assert_difference "Event.count", 1 do
      post events_path, params: {
        event: {
          title: "Guest trip"
        }
      }
    end

    assert_nil Event.last.user
  end

  test "signed in user creates event with user" do
    user = create_user

    post session_path, params: {
      email: user.email,
      password: "password123"
    }

    assert_difference "Event.count", 1 do
      post events_path, params: {
        event: {
          title: "User trip"
        }
      }
    end

    assert_equal user, Event.last.user
  end

  test "organizer can claim guest event after registration" do
    post events_path, params: {
      event: {
        title: "Guest trip"
      }
    }

    event = Event.last
    assert_nil event.user

    post registration_path, params: {
      user: {
        email: "owner@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    patch claim_event_path(event)

    assert_redirected_to dashboard_path
    assert_equal User.last, event.reload.user
  end

  test "guest organizer sees account prompt and returns to event after registration" do
    post events_path, params: {
      event: {
        title: "Guest trip"
      }
    }

    event = Event.last

    get event_share_path(event.access_token)

    assert_response :success
    assert_match "Сохраните мероприятие в аккаунте", response.body
    assert_match new_registration_path(return_to: event_share_path(event.access_token)), response.body

    post registration_path, params: {
      return_to: event_share_path(event.access_token),
      user: {
        email: "return@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to event_share_path(event.access_token)

    get event_share_path(event.access_token)

    assert_response :success
    assert_no_match "Сохраните мероприятие в аккаунте", response.body
    assert_match "Сохранить", response.body
  end

  test "receipt recognition button is hidden for guest event" do
    event = Event.create!(
      title: "Guest trip",
      organizer_token: "guest-receipt-button-token"
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_no_match "Распознать чек", response.body
  end

  test "receipt recognition button is hidden for free event owner" do
    user = create_user(plan: "free")
    event = Event.create!(
      title: "Free trip",
      organizer_token: "free-receipt-button-token",
      user:
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_no_match "Распознать чек", response.body
  end

  test "receipt recognition button is visible for pro event owner" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Pro trip",
      organizer_token: "pro-receipt-button-token",
      user:
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_match "Добавить чек", response.body
  end

  test "adding participant refreshes receipt upload action with add receipt link" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Receipt refresh trip",
      organizer_token: "receipt-refresh-token",
      user:
    )

    post event_participants_path(event),
         params: { participant: { name: "Катя" } },
         as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action='replace'][target='receipt_upload_action']"
    assert_includes response.body, "Добавить чек"
    assert_includes response.body, new_event_receipt_scan_path(event, access_token: event.access_token)
  end

  test "new event displays participants card with empty state and add form" do
    event = Event.create!(
      title: "Participants empty card trip",
      organizer_token: "participants-empty-card-token"
    )

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#participants .participants-card" do
      assert_select ".participants-card-title", "Участники"
      assert_select ".participants-empty-title", "Участников пока нет"
      assert_select ".participants-empty-text", "Добавьте людей, чтобы начать делить траты."
      assert_select "form.participant-form[action=?]", event_participants_path(event) do
        assert_select "input.participant-name-input[name='participant[name]']"
        assert_select "input.participant-submit[type='submit'][value='Добавить']"
      end
    end
  end

  test "adding participant refreshes participants card and progress card" do
    event = Event.create!(
      title: "Participants refresh card trip",
      organizer_token: "participants-refresh-card-token"
    )

    post event_participants_path(event),
         params: { participant: { name: "Катя" } },
         as: :turbo_stream

    assert_response :success
    participant = event.participants.find_by!(name: "Катя")

    assert_select "turbo-stream[action='replace'][target='participants']"
    assert_select "turbo-stream[action='replace'][target='event_progress']"
    assert_includes response.body, edit_event_participant_path(event, participant)
    assert_includes response.body, "participant-form"
    assert_no_match "Участников пока нет", response.body
  end

  test "participants card shows all five participant avatars" do
    event = Event.create!(
      title: "Five participants trip",
      organizer_token: "five-participants-token"
    )
    participants = 5.times.map { |index| event.participants.create!(name: "Участник #{index + 1}") }

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#participants .participants-avatar-row" do
      participants.each do |participant|
        assert_select "a[href=?]", edit_event_participant_path(event, participant)
      end
      assert_select "a.participants-overflow-link", count: 0
      assert_select "form.participant-form", count: 0
    end
    assert_select "#participants form.participant-form"
  end

  test "participants card shows all six participant avatars" do
    event = Event.create!(
      title: "Six participants trip",
      organizer_token: "six-participants-token"
    )
    participants = 6.times.map { |index| event.participants.create!(name: "Участник #{index + 1}") }

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#participants .participants-avatar-row" do
      participants.each do |participant|
        assert_select "a[href=?]", edit_event_participant_path(event, participant)
      end
      assert_select "a.participants-overflow-link", count: 0
    end
    assert_select "#participants form.participant-form"
  end

  test "participants card shows five avatars and overflow link for seven participants" do
    event = Event.create!(
      title: "Seven participants trip",
      organizer_token: "seven-participants-token"
    )
    participants = 7.times.map { |index| event.participants.create!(name: "Участник #{index + 1}") }

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#participants .participants-avatar-row" do
      participants.first(5).each do |participant|
        assert_select "a[href=?]", edit_event_participant_path(event, participant)
      end
      participants.last(2).each do |participant|
        assert_select "a[href=?]", edit_event_participant_path(event, participant), count: 0
      end
      assert_select "a.participants-overflow-link[href=?]", event_participants_sheet_path(event), text: "+2"
    end
    assert_select "#participants form.participant-form"
  end

  test "participants card shows five avatars and overflow link for thirteen participants" do
    event = Event.create!(
      title: "Thirteen participants trip",
      organizer_token: "thirteen-participants-token"
    )
    participants = 13.times.map { |index| event.participants.create!(name: "Участник #{index + 1}") }

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#participants .participants-avatar-row" do
      participants.first(5).each do |participant|
        assert_select "a[href=?]", edit_event_participant_path(event, participant)
      end
      participants.drop(5).each do |participant|
        assert_select "a[href=?]", edit_event_participant_path(event, participant), count: 0
      end
      assert_select "a.participants-overflow-link[href=?]", event_participants_sheet_path(event), text: "+8"
    end
    assert_select "#participants form.participant-form"
  end

  test "event show does not display separate receipt scans block" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Trip without checks",
      organizer_token: "empty-receipts-event-token",
      user:
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "h2", text: "Чеки", count: 0
    assert_no_match "Чеки пока не добавлены.", response.body
    assert_no_match "Можно сфотографировать чек, Анди распознает позиции и поможет добавить расходы.", response.body
    assert_select "a[href=?]",
                  new_event_receipt_scan_path(event, access_token: event.access_token),
                  text: "Добавить чек"
  end

  test "event show displays receipt link on expense created from receipt" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Trip with receipt",
      organizer_token: "receipt-card-event-token",
      user:
    )
    payer = event.participants.create!(name: "Катя")
    receipt_scan = create_receipt_scan_for_event(event, status: "processing")
    expense = event.expenses.create!(
      title: "Кофе",
      amount_cents: 12_000,
      payer:,
      receipt_scan:
    )
    expense.expense_shares.create!(participant: payer)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select ".expense-card", text: /Кофе/
    assert_select "a.expense-receipt-link[href*='/rails/active_storage/blobs'][target='_blank']", "📄 Чек"
    assert_no_match "Открыть чек", response.body
  end

  test "event show does not display receipt link on ordinary expense" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Trip with ordinary expense",
      organizer_token: "ordinary-expense-receipt-token",
      user:
    )
    payer = event.participants.create!(name: "Катя")
    expense = event.expenses.create!(
      title: "Такси",
      amount_cents: 45_000,
      payer:
    )
    expense.expense_shares.create!(participant: payer)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select ".expense-card", text: /Такси/
    assert_select "a.expense-receipt-link", count: 0
  end

  test "event show does not display unattached receipt scans" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Trip with ready receipt",
      organizer_token: "ready-receipt-card-event-token",
      user:
    )
    event.participants.create!(name: "Катя")
    create_receipt_scan_for_event(
      event,
      status: "ready",
      raw_result: { "items" => [ { "title" => "Кофе", "amount" => "120.00" } ] },
      recognized_items_count: 3,
      created_expenses_count: 2
    )

    get event_share_path(event.access_token)

    assert_response :success
    assert_select ".receipt-scan-card", count: 0
    assert_no_match "Распознан", response.body
    assert_no_match "Позиций: 3", response.body
    assert_no_match "Добавлено расходов: 2", response.body
  end

  test "event show does not display failed receipt scan status as separate card" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Trip with failed receipt",
      organizer_token: "failed-receipt-card-event-token",
      user:
    )
    event.participants.create!(name: "Катя")
    create_receipt_scan_for_event(event, status: "failed", error: "Фото слишком размыто")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select ".receipt-scan-card", count: 0
    assert_no_match "Ошибка распознавания", response.body
  end

  test "event without expenses displays expenses empty state actions" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Trip without expenses",
      organizer_token: "empty-expenses-token",
      user:
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#empty_expenses" do
      assert_select ".expenses-empty-title", "Пока нет трат"
      assert_select ".expenses-empty-text", text: /Добавьте первую покупку или загрузите чек/
      assert_select ".expenses-empty-text", text: /Анди автоматически посчитает/
      assert_select "a[href=?][data-turbo-frame='modal']", new_event_expense_path(event), text: "Добавить трату"
      assert_select "a[href=?]",
                    new_event_receipt_scan_path(event, access_token: event.access_token),
                    text: "Загрузить чек"
    end
  end

  test "event with expenses does not display expenses empty state" do
    user = create_user(plan: "pro")
    event = Event.create!(
      title: "Trip with expenses",
      organizer_token: "filled-expenses-token",
      user:
    )
    payer = event.participants.create!(name: "Катя")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 20_000,
      payer:
    )
    expense.expense_shares.create!(participant: payer)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#empty_expenses", count: 0
    assert_select ".expense-card", text: /Пицца/
  end

  test "new expense form defaults to equal split and includes quantity mode fields" do
    event = Event.create!(
      title: "Expense split form trip",
      organizer_token: "expense-split-form-token"
    )
    event.participants.create!(name: "Алиса")
    event.participants.create!(name: "Боб")

    get new_event_expense_path(event)

    assert_response :success
    assert_select "input[name='expense[split_mode]'][value='equal'][checked]"
    assert_select "input[name='expense[split_mode]'][value='quantity']"
    assert_select ".expense-share-weights[hidden]"
    assert_select ".expense-share-weights", text: /Сколько досталось каждому/
    assert_select ".expense-share-weights", text: /Укажите количество или доли/
    assert_no_match "Кто сколько взял / использовал", response.body
    assert_select "input[name^='expense[share_weights]']", count: 2
    assert_select "input.expense-share-weight-input[value='1']", count: 2
    assert_select "button.expense-share-weight-stepper[type='button'][aria-label='Уменьшить количество для Алиса'][data-action='click->expense-form#decrementWeight']", text: "−"
    assert_select "button.expense-share-weight-stepper[type='button'][aria-label='Увеличить количество для Алиса'][data-action='click->expense-form#incrementWeight']", text: "+"
    assert_select ".expense-share-weight-total", text: "Всего: 2 единицы"
  end

  test "weighted expense card shows quantity split label" do
    event = Event.create!(
      title: "Weighted card trip",
      organizer_token: "weighted-card-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Пиво",
      amount_cents: 100_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice, weight: 1)
    expense.expense_shares.create!(participant: bob, weight: 3)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select ".expense-card", text: /Пиво/ do
      assert_select ".expense-meta-secondary", text: /По количеству: 1 \/ 3/
    end
  end

  test "weighted expense edit form shows quantity mode with saved weights" do
    event = Event.create!(
      title: "Weighted edit form trip",
      organizer_token: "weighted-edit-form-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    sergey = event.participants.create!(name: "Сергей")
    expense = event.expenses.create!(
      title: "Пиво",
      amount_cents: 100_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice, weight: 7)
    expense.expense_shares.create!(participant: bob, weight: 1)
    expense.expense_shares.create!(participant: sergey, weight: 1)

    get edit_event_expense_path(event, expense)

    assert_response :success
    assert_select "input[name='expense[split_mode]'][value='quantity'][checked]"
    assert_select ".expense-share-weights[hidden]", count: 0
    assert_select ".expense-share-weights", text: /Сколько досталось каждому/
    assert_select "input[name='expense[share_weights][#{alice.id}]'][value='7']"
    assert_select "input[name='expense[share_weights][#{bob.id}]'][value='1']"
    assert_select "input[name='expense[share_weights][#{sergey.id}]'][value='1']"
    assert_select "button.expense-share-weight-stepper[type='button'][aria-label='Уменьшить количество для Алиса'][data-action='click->expense-form#decrementWeight']", text: "−"
    assert_select "button.expense-share-weight-stepper[type='button'][aria-label='Увеличить количество для Алиса'][data-action='click->expense-form#incrementWeight']", text: "+"
    assert_select ".expense-share-weight-fill[style='width: 100%']"
    assert_select ".expense-share-weight-fill[style='width: 14.29%']", count: 2
    assert_select ".expense-share-weight-total", text: "Всего: 9 единиц"
    assert_no_match "7.0", response.body
    assert_no_match "1.0", response.body
  end

  test "equal expense edit form keeps equal mode and hides histogram" do
    event = Event.create!(
      title: "Equal edit form trip",
      organizer_token: "equal-edit-form-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 50_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice, weight: 1)
    expense.expense_shares.create!(participant: bob, weight: 1)

    get edit_event_expense_path(event, expense)

    assert_response :success
    assert_select "input[name='expense[split_mode]'][value='equal'][checked]"
    assert_select ".expense-share-weights[hidden]"
  end

  test "weighted expense edit form formats fractional weights without trailing zeros" do
    event = Event.create!(
      title: "Weighted fractional edit form trip",
      organizer_token: "weighted-fractional-edit-form-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Сыр",
      amount_cents: 20_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice, weight: 0.5)
    expense.expense_shares.create!(participant: bob, weight: 1.25)

    get edit_event_expense_path(event, expense)

    assert_response :success
    assert_select "input[name='expense[share_weights][#{alice.id}]'][value='0.5']"
    assert_select "input[name='expense[share_weights][#{bob.id}]'][value='1.25']"
    assert_select ".expense-share-weight-total", text: "Всего: 1.75 единицы"
  end

  test "event without participants hides add expense empty state action" do
    event = Event.create!(
      title: "Trip without participants",
      organizer_token: "empty-expenses-no-participants-token"
    )

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#empty_expenses"
    assert_no_match "Добавить трату", response.body
    assert_no_match "Загрузить чек", response.body
  end

  test "creating expense records last event change description" do
    event = Event.create!(
      title: "Change reason trip",
      organizer_token: "expense-create-change-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")

    post event_expenses_path(event), params: {
      expense: {
        title: "Алкоголь",
        amount: "1200",
        payer_id: alice.id,
        participant_ids: [ alice.id, bob.id ]
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Добавлена трата «Алкоголь»", event.reload.last_change_description
    assert event.last_change_at.present?
    assert_equal [ BigDecimal("1"), BigDecimal("1") ],
                 event.expenses.find_by!(title: "Алкоголь").expense_shares.order(:participant_id).pluck(:weight)
  end

  test "creating weighted expense stores entered share weights" do
    event = Event.create!(
      title: "Weighted create trip",
      organizer_token: "weighted-create-token"
    )
    ivan = event.participants.create!(name: "Иван")
    petya = event.participants.create!(name: "Петя")
    sergey = event.participants.create!(name: "Сергей")

    post event_expenses_path(event), params: {
      expense: {
        title: "Пиво",
        amount: "1000",
        payer_id: ivan.id,
        split_mode: "quantity",
        participant_ids: [ ivan.id, petya.id, sergey.id ],
        share_weights: {
          ivan.id.to_s => "1",
          petya.id.to_s => "1",
          sergey.id.to_s => "8"
        }
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    expense = event.expenses.find_by!(title: "Пиво")
    assert_equal(
      {
        ivan.id => BigDecimal("1"),
        petya.id => BigDecimal("1"),
        sergey.id => BigDecimal("8")
      },
      expense.expense_shares.each_with_object({}) { |share, weights| weights[share.participant_id] = share.weight }
    )
  end

  test "weighted expense does not create zero weight shares" do
    event = Event.create!(
      title: "Weighted zero trip",
      organizer_token: "weighted-zero-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")

    post event_expenses_path(event), params: {
      expense: {
        title: "Фрукты",
        amount: "500",
        payer_id: alice.id,
        split_mode: "quantity",
        participant_ids: [ alice.id, bob.id ],
        share_weights: {
          alice.id.to_s => "1",
          bob.id.to_s => "0"
        }
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    expense = event.expenses.find_by!(title: "Фрукты")
    assert_equal [ alice.id ], expense.participant_ids
    assert_equal [ BigDecimal("1") ], expense.expense_shares.pluck(:weight)
  end

  test "weighted expense rejects all zero quantities" do
    event = Event.create!(
      title: "Weighted all zero trip",
      organizer_token: "weighted-all-zero-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")

    assert_no_difference "Expense.count" do
      post event_expenses_path(event), params: {
        expense: {
          title: "Фрукты",
          amount: "500",
          payer_id: alice.id,
          split_mode: "quantity",
          participant_ids: [ alice.id, bob.id ],
          share_weights: {
            alice.id.to_s => "0",
            bob.id.to_s => "0"
          }
        }
      }
    end

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Укажите количество больше 0 хотя бы для одного участника", flash[:alert]
  end

  test "weighted expense rejects negative quantities" do
    event = Event.create!(
      title: "Weighted negative trip",
      organizer_token: "weighted-negative-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")

    assert_no_difference "Expense.count" do
      post event_expenses_path(event), params: {
        expense: {
          title: "Фрукты",
          amount: "500",
          payer_id: alice.id,
          split_mode: "quantity",
          participant_ids: [ alice.id, bob.id ],
          share_weights: {
            alice.id.to_s => "1",
            bob.id.to_s => "-1"
          }
        }
      }
    end

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Введите неотрицательные количества", flash[:alert]
  end

  test "renaming expense records last event change description" do
    event = Event.create!(
      title: "Update change reason trip",
      organizer_token: "expense-update-change-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Такси",
      amount_cents: 150_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)

    patch event_expense_path(event, expense), params: {
      expense: {
        title: "Такси до дома",
        amount: "1500",
        payer_id: alice.id,
        participant_ids: [ alice.id, bob.id ]
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Переименована трата «Такси» → «Такси до дома»", event.reload.last_change_description
    assert event.last_change_at.present?
  end

  test "changing expense amount records last event change description" do
    event = Event.create!(
      title: "Amount change reason trip",
      organizer_token: "expense-amount-change-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Алкоголь",
      amount_cents: 120_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)

    patch event_expense_path(event, expense), params: {
      expense: {
        title: "Алкоголь",
        amount: "1500",
        payer_id: alice.id,
        participant_ids: [ alice.id, bob.id ]
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Изменена сумма траты «Алкоголь»", event.reload.last_change_description

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#event_status" do
      assert_select ".state-banner-title", "Расчёт изменился"
      assert_select ".state-banner-text", "Изменена сумма траты «Алкоголь»"
    end
    assert_select "#settlements" do
      assert_select ".expenses-empty-title", "Расчёт ещё не подтверждён"
      assert_select ".expenses-empty-text", text: /После подтверждения Анди покажет итоговые переводы/
      assert_select ".settlements-change-description", count: 0
    end
    assert_equal 1, response.body.scan("Изменена сумма траты «Алкоголь»").size
  end

  test "changing expense payer records last event change description" do
    event = Event.create!(
      title: "Payer change reason trip",
      organizer_token: "expense-payer-change-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Алкоголь",
      amount_cents: 120_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)

    patch event_expense_path(event, expense), params: {
      expense: {
        title: "Алкоголь",
        amount: "1200",
        payer_id: bob.id,
        participant_ids: [ alice.id, bob.id ]
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Изменён плательщик для траты «Алкоголь»", event.reload.last_change_description
  end

  test "changing expense participants records last event change description" do
    event = Event.create!(
      title: "Shares change reason trip",
      organizer_token: "expense-shares-change-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Алкоголь",
      amount_cents: 120_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)

    patch event_expense_path(event, expense), params: {
      expense: {
        title: "Алкоголь",
        amount: "1200",
        payer_id: alice.id,
        participant_ids: [ alice.id ]
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Изменён состав участников для траты «Алкоголь»", event.reload.last_change_description
  end

  test "changing expense weights records last event change description and unconfirms event" do
    event = Event.create!(
      title: "Weights change reason trip",
      organizer_token: "expense-weights-change-token",
      status: "confirmed"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Пиво",
      amount_cents: 100_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice, weight: 1)
    expense.expense_shares.create!(participant: bob, weight: 1)
    event.update!(status: "confirmed")

    patch event_expense_path(event, expense), params: {
      expense: {
        title: "Пиво",
        amount: "1000",
        payer_id: alice.id,
        split_mode: "quantity",
        participant_ids: [ alice.id, bob.id ],
        share_weights: {
          alice.id.to_s => "1",
          bob.id.to_s => "3"
        }
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    assert_predicate event.reload, :unconfirmed?
    assert_equal "Изменены доли для траты «Пиво»", event.last_change_description
    assert_equal [ BigDecimal("1"), BigDecimal("3") ], expense.reload.expense_shares.order(:participant_id).pluck(:weight)
  end

  test "deleting expense records last event change description" do
    event = Event.create!(
      title: "Delete change reason trip",
      organizer_token: "expense-delete-change-token"
    )
    alice = event.participants.create!(name: "Алиса")
    expense = event.expenses.create!(
      title: "Алкоголь",
      amount_cents: 120_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)

    delete event_expense_path(event, expense)

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Удалена трата «Алкоголь»", event.reload.last_change_description
    assert event.last_change_at.present?
  end

  test "creating participant records last event change description" do
    event = Event.create!(
      title: "Participant create change reason trip",
      organizer_token: "participant-create-change-token",
      status: "confirmed"
    )
    payer = event.participants.create!(name: "Алиса")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 120_000,
      payer:
    )
    expense.expense_shares.create!(participant: payer)
    event.update!(status: "confirmed")

    post event_participants_path(event), params: {
      participant: {
        name: "Саша"
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Добавлен участник «Саша»", event.reload.last_change_description
    assert_predicate event, :unconfirmed?
  end

  test "deleting participant records last event change description" do
    user = create_user
    event = user.events.create!(
      title: "Participant delete change reason trip",
      organizer_token: "participant-delete-change-token",
      status: "confirmed"
    )
    payer = event.participants.create!(name: "Алиса")
    participant = event.participants.create!(name: "Саша")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 120_000,
      payer:
    )
    expense.expense_shares.create!(participant: payer)
    expense.expense_shares.create!(participant:)
    event.update!(status: "confirmed")
    sign_in_as(user)

    delete event_participant_path(event, participant)

    assert_redirected_to event_share_path(event.access_token)
    assert_equal "Удалён участник «Саша»", event.reload.last_change_description
    assert_predicate event, :unconfirmed?
  end

  test "changed calculation details display in settlements card" do
    event = Event.create!(
      title: "Visible change reason trip",
      organizer_token: "visible-change-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")

    post event_expenses_path(event), params: {
      expense: {
        title: "Алкоголь",
        amount: "1200",
        payer_id: alice.id,
        participant_ids: [ alice.id, bob.id ]
      }
    }

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#event_status .event-status-pill", count: 0
    assert_no_match "Нужно подтвердить", response.body
    assert_select ".state-banner-warning" do
      assert_select ".state-banner-title", "Расчёт изменился"
      assert_select ".state-banner-text", text: /Добавлена трата «Алкоголь»/
      assert_select ".state-banner-time", text: /Только что/
      assert_select ".state-banner-text", text: /Проверьте траты перед подтверждением/, count: 0
    end

    assert_select "#settlements" do
      assert_select ".expenses-empty-title", "Расчёт ещё не подтверждён"
      assert_select ".expenses-empty-text", text: /После подтверждения Анди покажет итоговые переводы/
      assert_select ".settlements-change-description", count: 0
      assert_select ".settlements-change-time", count: 0
    end
    assert_equal 1, response.body.scan("Добавлена трата «Алкоголь»").size
    assert_no_match "Translation missing", response.body
  end

  test "settlements card keeps fallback text without last event change description" do
    event = Event.create!(
      title: "Fallback change reason trip",
      organizer_token: "fallback-change-token"
    )
    alice = event.participants.create!(name: "Алиса")
    expense = event.expenses.create!(
      title: "Такси",
      amount_cents: 150_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#event_status .event-status-pill", count: 0
    assert_select ".state-banner-warning" do
      assert_select ".state-banner-title", "Расчёт изменился"
      assert_select ".state-banner-text", text: /Проверьте траты перед подтверждением/
      assert_select ".state-banner-time", count: 0
    end

    assert_select "#settlements" do
      assert_select ".expenses-empty-title", "Расчёт ещё не подтверждён"
      assert_select ".expenses-empty-text", text: /После подтверждения Анди покажет итоговые переводы/
      assert_select ".settlements-change-description", count: 0
      assert_select ".settlements-change-time", count: 0
    end
  end

  test "event without expenses displays settlements empty state with add expense action" do
    event = Event.create!(
      title: "Trip without transfer data",
      organizer_token: "empty-settlements-token"
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#settlements" do
      assert_select ".expenses-empty-title", "Пока нечего переводить"
      assert_select ".expenses-empty-text", text: /Добавьте траты/
      assert_select ".expenses-empty-text", text: /Анди покажет переводы здесь/
      assert_select "a[href=?][data-turbo-frame='modal']", new_event_expense_path(event), text: "Добавить трату"
    end
  end

  test "event without expenses and participants hides settlements add expense action" do
    event = Event.create!(
      title: "Trip without transfer data or participants",
      organizer_token: "empty-settlements-no-participants-token"
    )

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#settlements" do
      assert_select ".expenses-empty-title", "Пока нечего переводить"
      assert_select ".expenses-empty-text", text: /Добавьте участников и траты/
      assert_select "a", count: 0
    end
  end

  test "new event displays progress card without creation step and participants as current step" do
    event = Event.create!(
      title: "Fresh progress trip",
      organizer_token: "fresh-progress-token"
    )

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#event_progress" do
      assert_select ".event-progress-title", "📋 Что осталось сделать"
      assert_select ".event-progress-item", text: /Создать мероприятие/, count: 0
      assert_select ".event-progress-item-current", text: /👉\s*Добавить участников/
      assert_select ".event-progress-item-pending", text: /⬜\s*Добавить траты/
      assert_select ".event-progress-item-pending", text: /⬜\s*Подтвердить расчёт/
      assert_select ".event-progress-item-pending", text: /⬜\s*Выполнить переводы/
    end
    assert_select "#event_status .event-status-pill", count: 0
    assert_select "#event_status .state-banner", count: 0
    assert_no_match "Черновик", response.body
  end

  test "event progress marks participants step completed" do
    event = Event.create!(
      title: "Participants progress trip",
      organizer_token: "participants-progress-token"
    )
    event.participants.create!(name: "Катя")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#event_progress" do
      assert_select ".event-progress-item-done", text: /✅\s*Добавить участников/
      assert_select ".event-progress-item-current", text: /👉\s*Добавить траты/
      assert_select ".event-progress-item-pending", text: /⬜\s*Подтвердить расчёт/
    end
  end

  test "event progress marks confirmation as current step when expenses exist" do
    event = Event.create!(
      title: "Expenses progress trip",
      organizer_token: "expenses-progress-token"
    )
    payer = event.participants.create!(name: "Катя")
    expense = event.expenses.create!(
      title: "Кофе",
      amount_cents: 12_000,
      payer:
    )
    expense.expense_shares.create!(participant: payer)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#event_progress" do
      assert_select ".event-progress-item-done", text: /✅\s*Добавить участников/
      assert_select ".event-progress-item-done", text: /✅\s*Добавить траты/
      assert_select ".event-progress-item-current", text: /👉\s*Подтвердить расчёт/
      assert_select ".event-progress-item-pending", text: /⬜\s*Выполнить переводы/
    end
  end

  test "event progress marks transfers as current step when confirmed calculation has unpaid settlements" do
    event = Event.create!(
      title: "Confirmed progress trip",
      organizer_token: "confirmed-progress-token",
      status: "confirmed"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 20_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)
    event.settlements.create!(
      from_participant: bob,
      to_participant: alice,
      amount_cents: 10_000,
      paid: false
    )
    event.update!(status: "confirmed")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#event_progress" do
      assert_select ".event-progress-title", "📋 Что осталось сделать"
      assert_select ".event-progress-item-done", text: /✅\s*Подтвердить расчёт/
      assert_select ".event-progress-item-current", text: /👉\s*Выполнить переводы/
    end
    assert_select "#event_status .event-status-pill", count: 0
    assert_select "#event_status .state-banner-success", count: 0
    assert_no_match "Расчёт подтверждён", response.body
  end

  test "unconfirmed event with expenses displays settlement confirmation state" do
    event = Event.create!(
      title: "Needs confirmation trip",
      organizer_token: "unconfirmed-settlements-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 20_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#event_status .event-status-pill", count: 0
    assert_no_match "Нужно подтвердить", response.body
    assert_select ".state-banner-warning" do
      assert_select ".state-banner-title", "Расчёт изменился"
    end
    assert_select "#settlements" do
      assert_select ".expenses-empty-title", "Расчёт ещё не подтверждён"
      assert_select ".expenses-empty-text", text: /После подтверждения Анди покажет итоговые переводы/
      assert_select "form[action=?]", event_confirmation_path(event), count: 0
    end

    assert_select "#confirm_bar" do
      assert_select "form[action=?]", event_confirmation_path(event) do
        assert_select "button", "Подтвердить"
      end
    end
  end

  test "confirming settlement calculation shows transfers" do
    event = Event.create!(
      title: "Confirm transfers trip",
      organizer_token: "confirm-settlements-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 20_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)

    patch event_confirmation_path(event)

    assert_redirected_to event_share_path(event.access_token)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#confirm_bar .confirm-bar", count: 0
    assert_select "#event_status .event-status-pill", count: 0
    assert_select "#event_status .state-banner-success", count: 0
    assert_select "#event_status .state-banner-title", text: "Расчёт подтверждён", count: 0
    assert_select "#settlements" do
      assert_select ".settlement-card", text: /Боб/
      assert_select ".settlement-card", text: /Алиса/
      assert_select ".expenses-empty-title", count: 0
    end
  end

  test "confirm bar returns after changing expenses on confirmed event" do
    event = Event.create!(
      title: "Reconfirm transfers trip",
      organizer_token: "reconfirm-settlements-token"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 20_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)

    patch event_confirmation_path(event)

    assert_redirected_to event_share_path(event.access_token)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#confirm_bar .confirm-bar", count: 0

    patch event_expense_path(event, expense), params: {
      expense: {
        title: "Пицца и сок",
        amount: "250",
        payer_id: alice.id,
        participant_ids: [ alice.id, bob.id ]
      }
    }

    assert_redirected_to event_share_path(event.access_token)
    assert_predicate event.reload, :unconfirmed?

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#settlements" do
      assert_select ".expenses-empty-title", "Расчёт ещё не подтверждён"
      assert_select "form[action=?]", event_confirmation_path(event), count: 0
    end
    assert_select "#confirm_bar" do
      assert_select "form[action=?]", event_confirmation_path(event) do
        assert_select "button", "Подтвердить"
      end
    end

    patch event_confirmation_path(event)

    assert_redirected_to event_share_path(event.access_token)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#confirm_bar .confirm-bar", count: 0
    assert_select "#settlements .settlement-card"
  end

  test "confirmed event with expenses and zero balance displays all split empty state" do
    event = Event.create!(
      title: "Already split trip",
      organizer_token: "split-settlements-token",
      status: "confirmed"
    )
    payer = event.participants.create!(name: "Катя")
    expense = event.expenses.create!(
      title: "Кофе",
      amount_cents: 12_000,
      payer:
    )
    expense.expense_shares.create!(participant: payer)
    event.update!(status: "confirmed")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#settlements" do
      assert_select ".expenses-empty-title", "Всё уже поделено"
      assert_select ".expenses-empty-text", text: /Сейчас никто никому ничего не должен/
      assert_select ".settlement-card", count: 0
    end
    assert_select "#event_progress" do
      assert_select ".event-progress-title", "📋 Что осталось сделать"
      assert_select ".event-progress-item-done", text: /✅\s*Всё поделено/
      assert_select ".event-progress-item-pending", count: 0
      assert_select ".event-progress-item-current", count: 0
    end
    assert_no_match "Пока нечего переводить", response.body
  end

  test "confirmed event with settlements displays transfer list without empty states" do
    event = Event.create!(
      title: "Transfers trip",
      organizer_token: "filled-settlements-token",
      status: "confirmed"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 20_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)
    event.settlements.create!(
      from_participant: bob,
      to_participant: alice,
      amount_cents: 10_000,
      paid: false
    )
    event.update!(status: "confirmed")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#settlements" do
      assert_select ".settlement-card", text: /Боб/
      assert_select ".settlement-card", text: /Алиса/
      assert_select ".expenses-empty-title", count: 0
    end
    assert_no_match "Пока нечего переводить", response.body
    assert_no_match "Всё уже поделено", response.body
  end

  test "event progress marks completed paid transfers" do
    event = Event.create!(
      title: "Paid progress trip",
      organizer_token: "paid-progress-token",
      status: "settled"
    )
    alice = event.participants.create!(name: "Алиса")
    bob = event.participants.create!(name: "Боб")
    expense = event.expenses.create!(
      title: "Пицца",
      amount_cents: 20_000,
      payer: alice
    )
    expense.expense_shares.create!(participant: alice)
    expense.expense_shares.create!(participant: bob)
    event.settlements.create!(
      from_participant: bob,
      to_participant: alice,
      amount_cents: 10_000,
      paid: true
    )
    event.update!(status: "settled")

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "#event_progress" do
      assert_select ".event-progress-title", "🎉 Мероприятие завершено"
      assert_select ".event-progress-summary", "Все переводы отмечены как оплаченные."
      assert_select ".event-progress-list", count: 0
      assert_select ".event-progress-item", count: 0
    end
    assert_equal 1, response.body.scan("Мероприятие завершено").size
    assert_select "#event_status .event-status-pill", count: 0
    assert_select "#event_status .state-banner-success", count: 0
    assert_no_match "Событие завершено", response.body
  end

  test "unknown event token returns not found" do
    get event_share_path("wrong-token")

    assert_response :not_found
    assert_includes response.body, "Такой страницы нет"
    assert_includes response.body, "/icons/android-192.png"
  end

  test "unknown event token returns not found for settlement pages" do
    get event_settlements_path("wrong-token")

    assert_response :not_found
    assert_includes response.body, "Такой страницы нет"
  end

  test "unknown event token returns not found for balance explanation" do
    get balance_explanation_path("wrong-token", 1, 2)

    assert_response :not_found
    assert_includes response.body, "Такой страницы нет"
  end

  test "unknown route returns not found page" do
    get "/%D1%84/wrong-token"

    assert_response :not_found
    assert_includes response.body, "Такой страницы нет"
  end

  test "settlements page has unified back link to event" do
    event = Event.create!(
      title: "Settlements back link",
      organizer_token: "settlements-back-link-token"
    )

    get event_settlements_path(event.access_token)

    assert_response :success
    assert_select "a.back-link[href=?]", event_share_path(event.access_token), text: "← К событию"
  end

  test "balance explanation page has unified back link to event" do
    event = Event.create!(
      title: "Balance back link",
      organizer_token: "balance-back-link-token"
    )
    from = event.participants.create!(name: "Миша")
    to = event.participants.create!(name: "Оля")
    expense = event.expenses.create!(
      title: "Пиво",
      amount_cents: 80_000,
      payer: to
    )
    expense.expense_shares.create!(participant: from)
    expense.expense_shares.create!(participant: to)
    event.settlements.create!(
      from_participant: from,
      to_participant: to,
      amount_cents: 40_000,
      paid: false
    )

    get balance_explanation_path(event.access_token, from, to)

    assert_response :success
    assert_select "a.back-link[href=?]", event_share_path(event.access_token), text: "← К событию"
    assert_includes response.body, "Анди уменьшает количество переводов"
    assert_select ".text-xs", text: "Доля в трате"
    assert_no_match "Доля в переводе", response.body
  end

  test "balance explanation shows raw equal split debt before optimization" do
    event = Event.create!(
      title: "Raw equal split explanation",
      organizer_token: "raw-equal-split-explanation-token"
    )
    aaa = event.participants.create!(name: "AAA")
    bbb = event.participants.create!(name: "BBB")
    ccc = event.participants.create!(name: "CCC")
    ddd = event.participants.create!(name: "DDD")
    expense = event.expenses.create!(
      title: "Фрукты",
      amount_cents: 40_000,
      payer: ddd
    )
    [ aaa, bbb, ccc, ddd ].each do |participant|
      expense.expense_shares.create!(participant:)
    end
    event.settlements.create!(
      from_participant: aaa,
      to_participant: ddd,
      amount_cents: 10_000,
      paid: false
    )

    get balance_explanation_path(event.access_token, aaa, ddd)

    assert_response :success
    assert_select "h4", text: "До взаимозачёта"
    assert_select "div", text: /AAA → DDD/
    assert_select "div", text: /за «Фрукты»/
    assert_select "div", text: /100 ₽/
  end

  test "balance explanation shows weighted raw debt before optimization" do
    event = Event.create!(
      title: "Raw weighted split explanation",
      organizer_token: "raw-weighted-split-explanation-token"
    )
    payer = event.participants.create!(name: "BBB")
    aaa = event.participants.create!(name: "AAA")
    petya = event.participants.create!(name: "Петя")
    expense = event.expenses.create!(
      title: "Пиво 10 банок",
      amount_cents: 100_000,
      payer:
    )
    expense.expense_shares.create!(participant: payer, weight: 1)
    expense.expense_shares.create!(participant: petya, weight: 1)
    expense.expense_shares.create!(participant: aaa, weight: 8)
    event.settlements.create!(
      from_participant: aaa,
      to_participant: payer,
      amount_cents: 80_000,
      paid: false
    )

    get balance_explanation_path(event.access_token, aaa, payer)

    assert_response :success
    assert_select "h4", text: "До взаимозачёта"
    assert_select "div", text: /AAA → BBB/
    assert_select "div", text: /за «Пиво 10 банок»/
    assert_select "div", text: /800 ₽/
    assert_select "div", text: /Разделили по количеству/
  end

  test "balance explanation shows before and after optimization with active selected transfer" do
    event = Event.create!(
      title: "Raw optimized explanation",
      organizer_token: "raw-optimized-explanation-token"
    )
    aaa = event.participants.create!(name: "AAA")
    bbb = event.participants.create!(name: "BBB")
    ddd = event.participants.create!(name: "DDD")

    beer = event.expenses.create!(
      title: "Пиво 10 банок",
      amount_cents: 80_000,
      payer: bbb
    )
    beer.expense_shares.create!(participant: aaa, weight: 1)

    fruit_from_aaa = event.expenses.create!(
      title: "Фрукты",
      amount_cents: 10_000,
      payer: ddd
    )
    fruit_from_aaa.expense_shares.create!(participant: aaa, weight: 1)

    fruit_from_bbb = event.expenses.create!(
      title: "Фрукты",
      amount_cents: 10_000,
      payer: ddd
    )
    fruit_from_bbb.expense_shares.create!(participant: bbb, weight: 1)

    event.settlements.create!(
      from_participant: aaa,
      to_participant: bbb,
      amount_cents: 70_000,
      paid: false
    )
    event.settlements.create!(
      from_participant: aaa,
      to_participant: ddd,
      amount_cents: 20_000,
      paid: false
    )

    get balance_explanation_path(event.access_token, aaa, bbb)

    assert_response :success
    assert_select "h3", text: "Как Анди упростил переводы"
    assert_select "h4", text: "До взаимозачёта"
    assert_select "h4", text: "После взаимозачёта"
    assert_select "div", text: /AAA → BBB/
    assert_select "div", text: /AAA → DDD/
    assert_select "div", text: /BBB → DDD/
    assert_select ".settlement-card-active", text: /AAA.*BBB/m do
      assert_select ".settlement-caption", text: "Выбранный перевод"
      assert_select ".settlement-amount", text: "700 ₽"
    end
    assert_select ".settlement-card", text: /AAA.*DDD/m do
      assert_select ".settlement-amount", text: "200 ₽"
    end
    assert_no_match "Доля в переводе", response.body
    assert_select ".text-xs", text: "Доля в трате"
  end

  test "organizer can open event settings" do
    post events_path, params: {
      event: {
        title: "Guest trip"
      }
    }

    event = Event.last

    get edit_event_path(event)

    assert_response :success
    assert_match "Настройки события", response.body
  end

  test "signed in registered event owner can open settings without organizer token" do
    user = create_user
    event = Event.create!(
      title: "Account settings trip",
      organizer_token: "owner-settings-token",
      user:
    )

    sign_in_as(user)

    get edit_event_path(event)

    assert_response :success
    assert_match "Настройки события", response.body
  end

  test "signed in registered event owner sees settings button without organizer token" do
    user = create_user
    event = Event.create!(
      title: "Account button trip",
      organizer_token: "owner-settings-button-token",
      user:
    )

    sign_in_as(user)
    get event_share_path(event.access_token)

    assert_response :success
    assert_select "a.settings-button[href=?]", edit_event_path(event)
  end

  test "signed in registered event owner can delete event without organizer token" do
    user = create_user
    event = Event.create!(
      title: "Account delete trip",
      organizer_token: "owner-delete-token",
      user:
    )

    sign_in_as(user)

    assert_difference "Event.count", -1 do
      delete event_path(event)
    end

    assert_redirected_to root_path
  end

  test "organizer token does not manage registered event for non owner" do
    post events_path, params: {
      event: {
        title: "Token cannot manage after claim"
      }
    }

    event = Event.last
    owner = create_user
    other_user = create_user
    event.update!(user: owner)

    sign_in_as(other_user)

    get edit_event_path(event)

    assert_redirected_to event_share_path(event.access_token)
  end

  test "organizer token does not show settings button for registered event non owner" do
    post events_path, params: {
      event: {
        title: "Token cannot see settings after claim"
      }
    }

    event = Event.last
    event.update!(user: create_user)

    get event_share_path(event.access_token)

    assert_response :success
    assert_select "a.settings-button", count: 0
  end

  test "non organizer can not open event settings" do
    event = Event.create!(
      title: "Someone else's trip",
      organizer_token: "other-token"
    )

    get edit_event_path(event)

    assert_redirected_to event_share_path(event.access_token)
  end

  test "guest organizer can still open guest event settings" do
    post events_path, params: {
      event: {
        title: "Legacy guest trip"
      }
    }

    event = Event.last

    get edit_event_path(event)

    assert_response :success
    assert_match "Настройки события", response.body
  end

  test "non organizer cannot claim event" do
    user = create_user
    event = Event.create!(
      title: "Someone else's trip",
      organizer_token: "other-token"
    )

    post session_path, params: {
      email: user.email,
      password: "password123"
    }

    patch claim_event_path(event)

    assert_redirected_to event_share_path(event.access_token)
    assert_nil event.reload.user
  end

  test "organizer token cannot claim registered event for another user" do
    post events_path, params: {
      event: {
        title: "Already claimed trip"
      }
    }

    event = Event.last
    owner = create_user
    other_user = create_user
    event.update!(user: owner)

    sign_in_as(other_user)

    patch claim_event_path(event)

    assert_redirected_to event_share_path(event.access_token)
    assert_equal owner, event.reload.user
  end

  test "registered event owner can delete participant without organizer token" do
    user = create_user
    event = Event.create!(
      title: "Participant owner trip",
      organizer_token: "participant-owner-token",
      user:
    )
    participant = event.participants.create!(name: "Катя")

    sign_in_as(user)

    assert_difference -> { event.participants.count }, -1 do
      delete event_participant_path(event, participant)
    end

    assert_redirected_to event_share_path(event.access_token)
  end

  test "organizer token does not delete participant on registered event for non owner" do
    post events_path, params: {
      event: {
        title: "Protected participant trip"
      }
    }

    event = Event.last
    event.update!(user: create_user)
    participant = event.participants.create!(name: "Катя")

    assert_no_difference -> { event.participants.count } do
      delete event_participant_path(event, participant)
    end

    assert_redirected_to event_share_path(event.access_token)
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email: user.email,
      password: "password123"
    }
  end

  def create_user(plan: "free")
    User.create!(
      email: "user-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      plan:
    )
  end

  def create_receipt_scan_for_event(event, attributes = {})
    receipt_scan = event.receipt_scans.build(attributes.reverse_merge(status: "pending"))
    receipt_scan.image.attach(
      io: Rails.root.join("test/fixtures/files/receipt.jpg").open,
      filename: "receipt.jpg",
      content_type: "image/jpeg"
    )
    receipt_scan.save!
    receipt_scan
  end
end
