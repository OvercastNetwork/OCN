PGM::Application.routes.draw do
    root :to => 'avatar#not_found'

    get '/:name/:size@2x.png', :to => 'avatar#show', :as => 'avatar'

    get "*path", :to => 'avatar#not_found'
end
