Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check
  match "ok", to: "security_test#ok", via: :all
  post "users/sign_in", to: "security_test#login"
  post "expensive", to: "security_test#expensive"
  match "api/test", to: "security_test#api", via: :all
  get "proxy-bucket", to: "security_test#proxy_bucket"
  get "admin", to: "security_test#ok"
  get ".well-known/acme-challenge/:token", to: "security_test#ok"
  get "image.php.jpg", to: "security_test#ok"
  get "search", to: "security_test#ok"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
