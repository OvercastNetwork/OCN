require 'test_helper'

class InlineAroundCallbackTest < ActiveSupport::TestCase

    # Test our monkey-patch of ActiveSupport::Callbacks allowing
    # around callbacks to be defined inline with a block,
    # and allowing them to yield to the event like the docs
    # tell you to do.
    test "block passed to inline around callback" do
        assert_raises ArgumentError do
            new_class do
                include ActiveSupport::Callbacks
                define_callbacks :woot
                set_callback(:woot, :around) {}
            end
        end
    end
end
