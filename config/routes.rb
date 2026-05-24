Rails.application.routes.draw do
  root "events#new"

  resources :events, only: [:new, :create, :edit, :update, :destroy]

  get "/e/:access_token", to: "events#show", as: :event_share

  resources :events, only: [] do
    resources :participants, only: [:create, :edit, :update, :destroy]
    resources :expenses, only: [:new, :create, :edit, :update, :destroy]
    get "participants_sheet", to: "participants#sheet", as: :participants_sheet
  end

  patch "/events/:event_id/confirm", to: "event_confirmations#update", as: :event_confirmation
  get "/e/:access_token/settlements", to: "settlements#index", as: :event_settlements

  get "/e/:access_token/why/:from_id/:to_id",
      to: "balance_explanations#show",
      as: :balance_explanation

  resources :settlements, only: [:update] do
    patch :unpay, on: :member
  end

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
