require 'continuation'

# Defines a callback called :test that fires for every test method,
# as well as shortcut methods #before_test, #around_test, and #after_test.
# The useful one is #around_test, which allows you to wrap tests and
# yield to them, something you can't do with setup and teardown.
module TestCallbacks
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    included do
        define_callbacks :test
        define_callback_macros :test
    end

    # This is a really hacky way of wrapping something around the test method,
    # but unfortunately, Minitest doesn't provide any easy way to do that.

    def after_setup
        super
        @name_without_callbacks = self.name
        self.name = :run_test
    end

    def run_test
        self.name = @name_without_callbacks

        @tests_ran = false
        run_callbacks :test do
            @tests_ran = true
            @test_return_value = __send__(name)
            true
        end
        @tests_ran or flunk "A callback prevented the test from running"

        @test_return_value
    end
end
