PGM::Application.routes.draw do
    get '/leaderboard', :to => 'users#leaderboard'
    get '/channels', :to => 'channels#index', :as => 'channels'
    get '/stats', :to => 'users#stats'
    get '/new_players', to: 'users#new_players'

    get '/:name', :to => 'users#show'
    get '/users/:name', :to => 'users#show'
    get '/:name/tp', :to => 'users#teleport'
    get '/users/:name/tp', :to => 'users#teleport'
end
