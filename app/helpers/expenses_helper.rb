module ExpensesHelper
  EXPENSE_PRESETS = [
    {
      emoji: "🍺",
      title: "Алкоголь",
      keywords: %w[
        алкоголь пиво водка коньяк виски вино шампанское просекко ром джин текила
        сидр настойка ликер ликёр мартини aperol апероль балтика corona heineken
        chivas jameson jack daniels absolut
      ]
    },
    {
      emoji: "🍎",
      title: "Фрукты",
      keywords: %w[
        фрукты фрукт яблоко яблоки банан бананы груша груши апельсин апельсины
        мандарин мандарины виноград киви манго ананас арбуз дыня персик нектарин
        гранат грейпфрут лимон лайм granny smith гренни смит
      ]
    },
    {
      emoji: "🥩",
      title: "Мясо / гриль",
      keywords: %w[
        шашлык мясо стейк стейки гриль мангал ребра рёбра курица свинина говядина
        баранина колбаски сосиски купаты бекон
      ]
    },
    {
      emoji: "🍕",
      title: "Еда",
      keywords: %w[
        еда пицца роллы суши бургер бургеры кафе ресторан закуски салат хлеб
        сыр колбаса рыба морепродукты креветки гребешок лосось форель
      ]
    },
    {
      emoji: "🥤",
      title: "Напитки",
      keywords: %w[
        напитки вода сок кола coca pepsi лимонад морс чай кофе энергетик минералка
      ]
    },
    {
      emoji: "🚕",
      title: "Транспорт",
      keywords: %w[
        такси uber яндекс таксомотор автобус метро поезд электричка бензин парковка
      ]
    },
    {
      emoji: "🎟",
      title: "Билеты",
      keywords: %w[
        билет билеты кино концерт театр музей вход аренда
      ]
    },
    {
      emoji: "🛒",
      title: "Другое",
      keywords: %w[
        другое разное мелочи хозтовары уголь салфетки посуда стаканы тарелки
      ]
    }
  ].freeze

  def expense_presets
    EXPENSE_PRESETS
  end

  def expense_icon(expense)
    text = normalize_expense_text(expense.title)

    preset = EXPENSE_PRESETS.find do |item|
      item[:title].downcase == text ||
        item[:keywords].any? { |keyword| text.include?(normalize_expense_text(keyword)) }
    end

    preset ? preset[:emoji] : "🛒"
  end

  private

  def normalize_expense_text(text)
    text.to_s
        .downcase
        .tr("ё", "е")
        .gsub(/[^\p{Alnum}\s]/, " ")
        .squeeze(" ")
        .strip
  end
end