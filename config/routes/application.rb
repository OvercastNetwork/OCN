PGM::Application.routes.draw do
    [400, 401, 403, 404, 422, 500].each do |status|
        get "/#{status}", to: 'errors#show', status: status
    end

    default_url_options :host => "localhost"
    mount Lockup::Engine, at: '/lockup' if ENV['LOCKUP_ENABLED']
    mount Peek::Railtie => "/peek"
    mount Forem::Engine, :at => "/forums"

    root :to => 'application#index'

    get '/terms', :to => 'application#terms'
    get '/privacy', :to => 'application#privacy'
    get '/refund', :to => 'application#refund'
    get '/donate', :to => 'application#donate'
    get '/live', :to => 'application#live'

    post '/inquire', :to => 'application#inquire'
    post '/autocomplete/:name', :to => 'application#autocomplete'
    get '/user_search', :to => 'application#user_search', :as => 'user_search'
    get '/model_search', :to => 'application#model_search', :as => 'model_search'
    put '/set_time_zone', :to => 'application#set_time_zone'
    get '/load_models', :to => 'application#load_models'

    resources :revisions
    resources :rules
    resources :staff

    resources :matches do
        member do
            post "validate"
        end
    end

    scope controller: 'maps', path: "/maps" do
        get action: 'now_playing', as: 'maps'
        get "all"
        get "gamemode/:gamemode", action: 'gamemode'
        get "rotation/:server", action: 'rotation'

        post "download/:id", action: 'download', as: 'download_map'
        get ":id", action: 'show', as: 'map'
    end

    resources :friendships do
        collection do
            get "pending"
            get "denied"
        end
    end

    resources :alerts do
        collection do
            post "read_all"
        end
    end

    resources :transactions do
        get "complete"
        get "cancel"
    end

    get "appeal", :to => "appeals#appeal", :as => :start_appeal
    resources :appeals do
        get 'latest'
        resources :actions do
            get "new/:type", :on => :collection, :action => :new
        end
    end

    get "report", :to => "reports#report", :as => :start_report
    resources :reports do
        get 'latest'
        get "new/:name", :on => :collection, :action => :new
        resources :actions do
            get "new/:type", :on => :collection, :action => :new
        end
    end

    resources :punishments do
        get "new/:name", :on => :collection, :action => :new
    end

    resources :tournaments do
        get "team/:team_id", action: :show_team, as: :show_team
        post "team/:team_id/accept", action: :accept_team, as: :accept_team
        post "team/:team_id/decline", action: :decline_team, as: :decline_team

        post "user/:user_id/add", action: :add_user, as: :add_user
        post "user/:user_id/remove", action: :remove_user, as: :remove_user
        post "user/:user_id/confirm", action: :confirm_user, as: :confirm_user
        post "user/:user_id/unconfirm", action: :unconfirm_user, as: :unconfirm_user
    end

    # NOTE: Any collection routes for teams must contain
    # an underscore, to prevent collisions with team slugs.
    resources :teams, path_names: {new: :new_team} do
        get 'register'
        post 'submit_registration'
        post 'unregister'
        post 'confirm_participation'
        post 'add_member'
        post 'remove_member'
        post 'update_invitation'
        post 'reassign_leader'
    end

    devise_for :users, :controllers => {:confirmations => "confirmations", :registrations => "registrations"}
    devise_scope :user do
        get '/login' => 'devise/sessions#new'
        post '/login' => 'devise/sessions#create'
        delete '/logout' => 'devise/sessions#destroy'

        post '/forgot' => 'devise/passwords#create'
        get '/forgot' => 'devise/passwords#new'
        get '/forgot/:reset_password_token' => 'devise/passwords#edit'
        put '/forgot' => 'devise/passwords#update'

        post '/register' => 'registrations#create'
        get '/register' => 'registrations#new'
        get '/account' => 'registrations#edit'
        put '/account' => 'registrations#update'

        get '/users/api_key' => 'registrations#api_key', as: :api_key
        post '/users/generate_api_key' => 'registrations#generate_api_key', as: :generate_api_key
        post '/users/revoke_api_key' => 'registrations#revoke_api_key', as: :revoke_api_key

        get '/oauth2authorize' => 'registrations#oauth2_authorize', as: :oauth2_authorize
        get '/oauth2callback'  => 'registrations#oauth2_callback'

        post '/confirm' => 'confirmations#create'
        get '/confirm' => 'confirmations#new'
        get '/confirm/:confirmation_token' => 'confirmations#show', as: :confirmify
        put '/confirm' => 'confirmations#confirm_account', as: :finalize_confirmation
    end
end
