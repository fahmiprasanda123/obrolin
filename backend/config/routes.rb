Rails.application.routes.draw do
  # Liveness/readiness probe target (returns 200 when the app boots).
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      delete "auth/logout", to: "auth#logout"

      resource :me, only: %i[show update], controller: "profiles"

      resources :workspaces, only: %i[index create show update] do
        resources :members, only: %i[index update destroy], controller: "workspace_members"
        resources :invitations, only: %i[index create destroy]
        resources :channels, only: %i[index create]
      end

      resources :channels, only: %i[show update] do
        member do
          post :join
          delete :leave
          post :read
        end
        resources :members, only: %i[index create], controller: "channel_members"
        resources :messages, only: %i[index create] do
          get :search, on: :collection
        end
      end

      resources :messages, only: %i[update destroy] do
        get :replies, on: :member
        resources :reactions, only: :create
      end

      get "invitations/:token", to: "invitation_acceptances#show", as: :invitation_preview
      post "invitations/:token/accept", to: "invitation_acceptances#create", as: :invitation_accept
    end
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
