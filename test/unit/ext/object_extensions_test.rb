require 'test_helper'

class ObjectExtensionsTest < ActiveSupport::TestCase
    test "transform_if with false condition" do
        assert_equal 1, 1.transform_if(nil) {|n| n + 1 }
        assert_equal 1, 1.transform_if(false) {|n| n + 1 }
    end

    test "transform_if with true condition" do
        assert_equal 2, 1.transform_if(true) {|n| n + 1 }
    end

    test "transform_if with conditional parameter" do
        assert_equal 1, 3.transform_if(2) {|n, i| n - i }
        assert_equal 1, 3.transform_if(2, &:-)
    end

    test "boolean cast" do
        assert_equal false, nil.to_bool
        assert_equal false, false.to_bool

        assert_equal true, Object.new.to_bool
        assert_equal true, true.to_bool
        assert_equal true, 0.to_bool
        assert_equal true, ''.to_bool
        assert_equal true, 'false'.to_bool
    end

    test "boolean parse" do
        assert_equal true, 'true'.parse_bool
        assert_equal true, 'on'.parse_bool
        assert_equal true, 'yes'.parse_bool
        assert_equal true, '1'.parse_bool

        assert_equal false, 'false'.parse_bool
        assert_equal false, 'off'.parse_bool
        assert_equal false, 'no'.parse_bool
        assert_equal false, '0'.parse_bool
        assert_equal false, 'giraffe'.parse_bool
        assert_equal false, ''.parse_bool
    end
end
