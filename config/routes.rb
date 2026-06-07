Rails.application.routes.draw do
  root "events#new"

  resources :events, only: [ :new, :create, :edit, :update, :destroy ]

  get "/e/:access_token", to: "events#show", as: :event_share

  resources :events, only: [] do
    resources :participants, only: [ :create, :edit, :update, :destroy ]
    resources :expenses, only: [ :new, :create, :edit, :update, :destroy ]
    get "participants_sheet", to: "participants#sheet", as: :participants_sheet
  end

  patch "/events/:event_id/confirm", to: "event_confirmations#update", as: :event_confirmation
  get "/e/:access_token/settlements", to: "settlements#index", as: :event_settlements

  get "/e/:access_token/why/:from_id/:to_id",
      to: "balance_explanations#show",
      as: :balance_explanation

  resources :settlements, only: [ :update ] do
    patch :unpay, on: :member
  end

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "/sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }
  get "/privacy", to: "pages#privacy", as: :privacy
  get "/terms", to: "pages#terms", as: :terms

  get "/razdelit-rashody", to: "seo_pages#split_expenses", as: :split_expenses
  get "/razdelit-rashody-v-poezdke", to: "seo_pages#trip_expenses", as: :trip_expenses
  get "/picnic-expenses", to: "seo_pages#picnic_expenses", as: :picnic_expenses
  get "/razdelit-rashody-na-piknike", to: "seo_pages#picnic_expenses", as: :picnic_expenses_ru
  get "/party-expenses", to: "seo_pages#party_expenses", as: :party_expenses
  get "/razdelit-rashody-na-vecherinke", to: "seo_pages#party_expenses", as: :party_expenses_ru
  get "/kto-komu-skolko-dolzhen", to: "seo_pages#who_owes_whom", as: :who_owes_whom

  resource :registration, only: [ :new, :create ]
  resource :session, only: [ :new, :create, :destroy ]
  get "/dashboard", to: "dashboard#index", as: :dashboard

  patch "/events/:id/claim", to: "events#claim", as: :claim_event
end
