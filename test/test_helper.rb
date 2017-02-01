ENV["RAILS_ENV"] = "test"

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'mocha/mini_test'

Rails.application.eager_load!

# Don't hide stack traces for tests
Rails.backtrace_cleaner.remove_silencers!

require 'minitest/reporters'
MiniTest::Reporters.use!

Dir.glob(File.expand_path('helpers/*.rb', File.dirname(__FILE__))) do |fn|
    require fn.sub(/\.rb\z/, '')
end

class ActiveSupport::TestCase
    include TestCallbacks
    include FreezeTime
    include TemporaryConstants
    include HttpTestHelpers
    include FactoryGirl::Syntax::Methods
    include CacheTestHelpers
    include MongoSetupAndTeardown
    include RedisSetupAndTeardown

    include MongoidTestHelpers

    include Assertions
    include MongoidAssertions

    include GlobalFixtures

    around_test do |_, block|
        Logging.stdout do
            block.call
        end
    end
end

class ActionController::TestCase
    include FactoryGirl::Syntax::Methods
    include Devise::TestHelpers
    include MongoSetupAndTeardown
    include RedisSetupAndTeardown

    include Assertions
    include MongoidAssertions
    include ControllerTest
end
