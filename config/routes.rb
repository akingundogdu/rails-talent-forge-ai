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

      # Performance Management Routes
      resources :performance_reviews do
        member do
          post :submit
          post :approve
          post :complete
          get :feedback_summary
          get :summary
        end
        collection do
          get :analytics
        end
        
        resources :goals, except: [:show], controller: 'goals', action: 'by_review'
        resources :feedbacks, except: [:show], controller: 'feedbacks', action: 'by_review'
        resources :ratings, except: [:show], controller: 'ratings', action: 'by_review'
      end

      resources :goals do
        member do
          put :update_progress
          post :complete
          post :pause
          post :resume
          post :cancel
        end
        collection do
          post :bulk_update_progress
          get :overdue
          get :due_soon
          get :analytics
        end
      end

      resources :kpis do
        member do
          put :update_progress
          post :complete
          post :archive
        end
        collection do
          get :dashboard
          get :benchmarks
          get :trending
          get :trends
          get :analytics
          post :bulk_create_for_position
          post :bulk_update
        end
      end

      resources :feedbacks do
        member do
          put :update_feedback
        end
        collection do
          post :request_peer_feedback
          post :request_feedback
          post :create_360_request
          get :analytics
          get :trends
          get :themes
          get :summary
        end
      end

      resources :ratings do
        collection do
          post :bulk_create_for_review
          get :competency_benchmarks
          get :department_gaps
        end
      end

      # Performance Analytics Routes
      namespace :analytics do
        resources :performance, only: [] do
          collection do
            get :summary
            get :department_metrics
            get :employee_trends
            get :competency_analysis
          end
        end
      end
    end
  end
end
