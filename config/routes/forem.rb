Forem::Engine.routes.draw do
    root :to => "forums#index"

    # ME ROUTES
    get 'my_subscriptions', :to => "topics#my_subscriptions"
    get 'my_topics', :to => "topics#my_topics"
    get 'my_posts', :to => "topics#my_posts"

    post 'clear_subscriptions', :to => 'topics#clear_subscriptions'

    # NEW ROUTES
    resources :forums, :path => "/" do
        member do
            post :mark_read
        end
    end

    get ':forum_id/topics/new', to: 'topics#new', as: :new_topic
    post ':forum_id/topics', to: 'topics#create', as: :create_topic

    resources :topics, :path => "/topics" do
        resources :posts do
            member do
                post :pin
            end
        end
        member do
            put :toggle_hide
            put :toggle_lock
            put :toggle_pin
            post :subscribe
            post :unsubscribe
            get :unread
        end
    end

    resources :categories

    # REDIRECT OLD ROUTES
    get '/forums/:forum_id/', :to => "redirect#forum"
    get '/forums/:forum_id/topics/:topic_id', :to => "redirect#topic"
    get '/posts/:post_id', :to => "redirect#posts", :as => :post
    get '/subscriptions', :to => "redirect#subscriptions"

    # MODERATION
    put '/:forum_id/moderate/posts', :to => "moderation#posts", :as => :forum_moderate_posts
end
