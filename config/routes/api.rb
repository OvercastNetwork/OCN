PGM::Application.routes.draw do
    scope module: 'api' do
        root :to => 'api#index'

        models :users do
            collection do
                get "by_username/:username", action: :by_username
                post "search"
                post "by_uuid"
                post "login"
            end

            member do
                post "logout"
                post "purchase_gizmo"
                post "credit_tokens"
                post "join_friend"
                post "change_group"
                post "change_setting"
                post "change_class"
            end
        end

        resources :servers do
            collection do
                get "by_name/:name_search", action: :by_name
                post "staff"
                post "search"
                post "metric"
                post "ping"
            end
        end

        models :sessions do
            collection do
                get "online/:player_id", action: :online
                get "friends/:player_id", action: :friends
                post "start"
            end
            member do
                post "finish"
            end
        end

        models :friendships do
            collection do
                post "create"
                post "destroy"
                post "list"
            end
        end

        models :maps do
            member do
                post :rate
                post :get_ratings
            end
        end

        models :whispers do
            collection do
                get "reply/:user_id", action: :reply
            end
        end

        models :tournaments do
            member do
                get :teams
                get "entrants/:team_id", action: :entrants
                get :entrants
                post :record_match
            end
        end

        models :matches
        models :participations
        models :games
        models :reports
        models :deaths
        models :objectives
        models :punishments
    end
end
