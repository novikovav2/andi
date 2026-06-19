module ApplicationHelper
  def participant_initials(name)
    name.to_s.split.map { |part| part[0] }.join.first(2).upcase
  end

  def participant_color(participant)
    colors = [
      "avatar-blue",
      "avatar-green",
      "avatar-amber",
      "avatar-purple",
      "avatar-pink",
      "avatar-cyan"
    ]

    colors[participant.id % colors.size]
  end

  def rubles(cents)
    number_to_currency(
      cents / 100.0,
      unit: "₽",
      precision: 0,
      delimiter: " ",
      separator: ".",
      format: "%n %u"
    )
  end

  def receipt_amount(amount)
    normalized = amount.to_s.strip.tr(",", ".").gsub(/\s+/, "")
    decimal = BigDecimal(normalized)
    cents = (decimal * 100).round.to_i
    precision = cents % 100 == 0 ? 0 : 2

    number_to_currency(
      decimal,
      unit: "₽",
      precision:,
      delimiter: " ",
      separator: ".",
      format: "%n %u"
    )
  rescue ArgumentError
    "#{amount} ₽"
  end

  def time_ago_in_russian(time)
    return "" if time.blank?

    seconds = Time.current - time

    case seconds
    when 0...60
      "Только что"
    when 60...(60 * 60)
      minutes = (seconds / 60).to_i
      "#{minutes} #{russian_plural(minutes, 'минуту', 'минуты', 'минут')} назад"
    when (60 * 60)...(24 * 60 * 60)
      hours = (seconds / 3600).to_i
      "#{hours} #{russian_plural(hours, 'час', 'часа', 'часов')} назад"
    when (24 * 60 * 60)...(30 * 24 * 60 * 60)
      days = (seconds / 86_400).to_i
      "#{days} #{russian_plural(days, 'день', 'дня', 'дней')} назад"
    else
      I18n.l(time, format: "%d.%m.%Y")
    end
  end

  def russian_plural(number, one, few, many)
    number = number.to_i
    last_two_digits = number % 100

    return many if last_two_digits.between?(11, 14)

    case number % 10
    when 1
      one
    when 2..4
      few
    else
      many
    end
  end
end
