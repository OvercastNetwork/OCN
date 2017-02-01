PGM::Application.routes.draw do
    get '/play', :to => 'play#index', :as => 'play'
    get '/play/:portal', :to => 'play#index', :as => 'portal'
    get '/play/:portal/:server/tp', :to => 'play#teleport', :as => 'server_teleport'
end
