# frozen_string_literal: true

Automator::Engine.routes.draw do
  root to: "dashboard#show"
  post "sweep", to: "dashboard#sweep", as: :sweep
  get "metrics.json", to: "dashboard#metrics", as: :metrics

  resources :flows do
    member do
      post :toggle
      get :simulate
      post :run_simulate
    end
  end

  resources :jobs, only: %i[index show] do
    member do
      post :retry
      post :cancel
    end
  end

  resources :executions, only: %i[index show]
  resources :tenants, only: :index
end
