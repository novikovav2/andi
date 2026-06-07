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
end
