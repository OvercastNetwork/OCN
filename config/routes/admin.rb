PGM::Application.routes.draw do
    namespace :admin do
        root :to => "base#index"

        get '/raise', to: 'base#test_error'

        resources :groups do
            resources :members
        end

        resources :forums do
            resources :moderators
        end

        resources :categories

        resources :transactions do
            member do
                post :give_package
                post :revoke_package
                post :refund
            end
        end

        resources :trophies do
            collection do
                post :update_membership
            end
        end

        resources :tournaments

        resources :streams

        resources :banners

        resources :servers do
            collection do
                post :restart_lobbies
                post :sync_dns
            end
            member do
                get :clone
            end
        end

        resources :ipbans

        resources :users do
            member do
                post :become, :param => :player_id
                post :clear_channels, :param => :player_id
            end
        end

        resources :sessions

        resources :git do
            collection do
                post :event
            end
        end

        resources :repositories do
            member do
                post :build
            end
        end

        resources :charts do
            collection do
                post :data
            end
        end

        resources :data do
            collection do
                post :validate
                get :pull
                get :permissions
            end
        end
    end
end
