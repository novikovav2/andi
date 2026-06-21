module EventsHelper
  def event_status_label(event)
    case event.status
    when "draft"
      "Черновик"
    when "unconfirmed"
      "Нужно подтвердить"
    when "confirmed"
      "Подтверждено"
    when "settled"
      "Завершено"
    else
      event.status
    end
  end

  def event_progress_steps(event)
    participants_done = event.participants.any?
    expenses_done = event.expenses.any?
    calculation_done = event.confirmed? || event.settled?
    settlements = event.settlements
    zero_balance_done = calculation_done && expenses_done && settlements.none?
    transfers_done = settlements.any? && settlements.all?(&:paid?)
    current_step =
      if !participants_done
        "Добавить участников"
      elsif !expenses_done
        "Добавить траты"
      elsif !calculation_done
        "Подтвердить расчёт"
      elsif settlements.any? && !transfers_done
        "Выполнить переводы"
      end

    [
      event_progress_step("Добавить участников", participants_done, current_step),
      event_progress_step("Добавить траты", expenses_done, current_step),
      event_progress_step("Подтвердить расчёт", calculation_done, current_step),
      event_progress_step(zero_balance_done ? "Всё поделено" : "Выполнить переводы",
                          zero_balance_done || transfers_done,
                          current_step)
    ]
  end

  def event_progress_completed?(event)
    event.settlements.any? && event.settlements.all?(&:paid?)
  end

  private

  def event_progress_step(label, done, current_step)
    status =
      if done
        :done
      elsif label == current_step
        :current
      else
        :pending
      end

    { label:, status: }
  end
end
