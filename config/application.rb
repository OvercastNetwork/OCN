# Uncomment this if you ever need to debug a SystemStackError
# require File.expand_path('../../lib/stack_overflow_backtrace', __FILE__)
# StackOverflowBacktrace.install

require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"
require "action_mailer/railtie"
require "rails/test_unit/railtie"
require "sprockets/railtie"

require 'net/smtp'
Net.instance_eval {remove_const :SMTPSession} if defined?(Net::SMTPSession)

require 'net/pop'
Net::POP.instance_eval {remove_const :Revision} if defined?(Net::POP::Revision)
Net.instance_eval {remove_const :POP} if defined?(Net::POP)
Net.instance_eval {remove_const :POPSession} if defined?(Net::POPSession)
Net.instance_eval {remove_const :POP3Session} if defined?(Net::POP3Session)
Net.instance_eval {remove_const :APOPSession} if defined?(Net::APOPSession)

require 'tlsmail'

if defined?(Bundler)
    # If you precompile assets before deploying to production, use this line
    Bundler.require(*Rails.groups(:assets => %w(development test)))
    # If you want your assets lazily compiled in production, use this line
    # Bundler.require(:default, :assets, Rails.env)
end

module ORG
    NAME = "Stratus Network"
    DOMAIN = "stratus.network"
    SHOP = "shop.#{DOMAIN}"
    EMAIL = "networkstratus@gmail.com"
end

module PGM
    class Application < Rails::Application
        class << self
            def ocn_role
                ENV['OCN_ROLE'] || 'octc'
            end

            # Used to switch route config during tests
            def ocn_role=(role)
                unless role == ocn_role
                    ENV['OCN_ROLE'] = role
                    Rails.application.reload_routes! if Rails.application
                end
            end
        end

        def after_fork(&block)
            (@after_fork_callbacks ||= []) << block
        end

        def run_after_fork_callbacks
            @after_fork_callbacks.each(&:call) if @after_fork_callbacks
        end

        # custom error routes
        config.exceptions_app = self.routes

        # Settings in config/environments/* take precedence over those specified here.
        # Application configuration should go into files in config/initializers
        # -- all .rb files in that directory are automatically loaded.

        # Custom directories with classes and modules you want to be autoloadable.
        config.autoload_paths << "#{config.root}/lib"

        # Only load the plugins named here, in the order given (default is alphabetical).
        # :all can be used as a placeholder for all plugins not explicitly named.
        # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

        # Activate observers that should always be running.
        # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

        # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
        # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
        # config.time_zone = 'Central Time (US & Canada)'

        # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
        # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
        # config.i18n.default_locale = :de

        # Configure the default encoding used in templates for Ruby 1.9.
        config.encoding = "utf-8"

        # Configure sensitive parameters which will be filtered from the log file.
        config.filter_parameters += [:password]

        # Enable the asset pipeline
        config.assets.enabled = true

        # Version of your assets, change this if you want to expire all your assets
        config.assets.version = '1.1'

        # Time Zone is CST
        config.time_zone = 'Central Time (US & Canada)'

        # Include process ID in logs
        config.log_tags = [-> (req) { "PID #{$$}" }]
        config.log_level = :info

        # Generate a sentry event if a database query takes longer than this
        config.query_time_limit = 10.seconds

        # Disable ActiveDispatch's "deep munge" security hack (it breaks all kinds of stuff)
        # http://stackoverflow.com/questions/14647731/
        config.action_dispatch.perform_deep_munge = false
    end
end
