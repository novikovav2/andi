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
end