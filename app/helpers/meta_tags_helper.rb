module MetaTagsHelper
  def default_meta_tags
    {
      site: "Анди",
      reverse: true,
      title: "Справедливое разделение расходов",
      description: "Учитывайте кто что покупал, ел и пил. Анди автоматически рассчитает кто кому сколько должен.",
      keywords: %w[
        расходы
        поездка
        друзья
        вечеринка
        пикник
        корпоратив
        расчёт
      ],
      canonical: request.original_url,
      noindex: !Rails.env.production?,
      og: {
        site_name: "Анди",
        title: :title,
        description: :description,
        type: "website",
        url: request.original_url,
        image: {
          _: "#{request.base_url}/og-image.jpg",
          width: 1200,
          height: 630
        },
        twitter: {
          card: "summary_large_image",
          title: "Анди — справедливое разделение расходов",
          description: "Анди рассчитает кто кому сколько должен после общего мероприятия.",
          image: "#{request.base_url}/og-trip-expenses-hero-mobile.png"
        }
      }
    }
  end
end
