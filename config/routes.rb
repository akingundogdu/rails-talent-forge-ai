Rails.application.routes.draw do
  devise_for :users
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  root 'home#index'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      devise_for :users, controllers: {
        sessions: 'api/v1/users/sessions',
        registrations: 'api/v1/users/registrations'
      }
      
      resources :users, only: [:show, :update] do
        resources :permissions, only: [:index, :create, :destroy]
      end

      resources :users, only: [] do
        collection do
          post :sign_in
          post :sign_up
          delete :sign_out
          get :profile
          put :update_profile
          put :change_password
        end
      end

      resources :departments do
        member do
          get :employees
          get :positions
        end
        collection do
          get :tree
          post :bulk_create
        end
        
        resources :positions, only: [:index], controller: 'positions', action: 'by_department'
        resources :employees, only: [:index], controller: 'employees', action: 'by_department'
      end

      resources :positions do
        member do
          get :employees
        end
        collection do
          get :tree
          post :bulk_create
        end
        
        resources :employees, only: [:index], controller: 'employees', action: 'by_position'
      end

      resources :employees do
        member do
          get :subordinates
          get :manager
        end
        collection do
          get :search
          post :bulk_create
        end
      end

      resources :permissions, only: [:index, :show, :create, :update, :destroy] do
        collection do
          post :bulk_create
        end
      end
    end
  end
end
