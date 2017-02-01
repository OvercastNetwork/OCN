require 'test_helper'

# Meta-tests of things used by the test environment
class TestingEnvironmentTest < ActiveSupport::TestCase
    around_test do |_, block|
        @around_test_before = true
        block.call
        @around_test_after = true
    end

    test "around test callback works" do
        assert @around_test_before
        refute @around_test_after
    end

    teardown do
        assert @around_test_after
    end

    test "time frozen" do
        assert Timecop.frozen?
    end
end
