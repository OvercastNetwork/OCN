PGM::Application.routes.draw do
	get  '/shop', :to => 'shop#index'
	post '/shop/status', :to => 'shop#status'
	post '/shop/purchase', :to => 'shop#purchase'
	get  '/shop/thanks', :to => 'shop#thanks'
end
