# NOTE: If any native extensions fail to build on OSX, try opening XCode and accepting the EULA.
# Apple likes to update their EULA and silently break all build tools until you read their mind.

source 'http://rubygems.org'

gem 'rails', '~> 4.2'                   # Ruby on Rails
gem 'protected_attributes'
gem 'bundler'                           # Gem management
gem 'mongoid', '~> 5.0.0'               # MongoDB ORM
gem 'jquery-rails'                      # Regular jQuery and UJS
gem 'json'
gem 'haml'
#gem 'capistrano', '2.15.5'              # Deployment
gem 'uuid'
gem 'devise'                            # User registration and authentication
gem 'tlsmail'
gem 'kaminari'                          # Pagination
gem 'simple_form'
gem 'workflow', '1.0.0'
gem 'workflow_on_mongoid'
gem 'git'
gem 'activemerchant'
gem 'nokogiri'
gem 'sanitize', '2.1.0'
gem 'redis'
gem 'github_api'
gem 'gitlab'
gem 'peek'
gem 'peek-redis'
gem 'peek-rblineprof', :platform => :ruby # doesn't work on Windows
gem 'peek-performance_bar'
gem 'peek-git'
gem 'jwt'
gem 'netaddr', '~> 1.5.0'
gem 'tzinfo'
gem 'tzinfo-data'
gem 'rack-timeout'
gem 'rails_autolink'
gem 'utf8-cleaner'
gem 'redcarpet'                         # Markdown parser
gem 'gemoji'
gem 'chronic'                           # Natural language time parsing
gem 'cloudflare'                        # CloudFlare HTTP API wrapper
gem 'uuidtools'
gem 'bunny'                             # AMQP client
gem 'dante'                             # Daemonizing tools (for worker daemon)
gem 'trollop'                           # Command-line options parsing
gem 'sentry-raven'                      # Error reporting
gem 'serverengine'                      # Pre-fork daemon framework used for workers
gem 'select2-rails'                     # Select2 jQuery widget, Rails integration
gem 'dogapi'                            # DataDog API client
gem 'chunky_png'                        # Image processor (used for skins)
gem 'google-api-client'                 # Client for all things Google
gem 'braintree'                         # Payment processor
gem 'geoip'                             # IP lookup utility
gem 'droplet_kit'                       # Digital Ocean client
gem 'net-http-pipeline'
gem 'crowdin-api', github: 'OvercastNetwork/crowdin-api', branch: 'master'

# CouchDB ORM - forked to fix date serialization format
gem 'couch_potato', :github => 'OvercastNetwork/couch_potato', :branch => 'master', :ref => '7c55e77cf25f30a0878b7d0425fc3b87e83e33b2'

gem 'reverse_markdown', :github => 'OvercastNetwork/reverse_markdown', :branch => 'master'
gem 'ruby-string-match-scorer', :github => 'bjeanes/ruby-string-match-scorer'

group :production, :staging do
    gem 'unicorn'                       # Web server
#    gem 'rvm-capistrano'                # RVM deploy integration
#    gem 'capistrano-unicorn'            # Unicorn deploy integration
    gem 'sass-rails'                    # CSS and JS minification
    gem 'coffee-rails'                  # CSS and JS minification
    gem 'uglifier'                      # CSS and JS minification
    gem 'therubyracer'                  # CSS and JS minification
end

group :development do
    gem 'eventmachine', :github => 'eventmachine/eventmachine' # Thin depend, need latest for Windows
    gem 'thin'                          # Web server
    gem 'better_errors'
    gem 'binding_of_caller'
    gem 'print_members', :github => 'jedediah/print_members' # IRB reflection tool
end

group :test do
    gem 'minitest'
    gem 'minitest-reporters', '>= 0.5.0'
    gem 'factory_girl_rails', '~> 4.0'
    gem 'timecop'
    gem 'mocha' # Mocking and stubbing
end
