class PagesController < ApplicationController
  def privacy
    set_meta_tags(
      title: "Политика конфиденциальности",
      description: "Как Анди обрабатывает данные, cookies и аналитику."
    )
  end

  def terms
    set_meta_tags(
      title: "Пользовательское соглашение",
      description: "Короткие правила использования сервиса Анди."
    )
  end
end
