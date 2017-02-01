require 'test_helper'

class InheritedAttributesTest < ActiveSupport::TestCase
    test "nil value" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited :woot
        end

        assert_nil a.woot
    end

    test "default value" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited(:woot) { 123 }
        end

        assert_equal 123, a.woot
    end

    test "assigned value" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited :woot
        end

        a.woot = 123
        assert_equal 123, a.woot
    end

    test "inherited value" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited :woot
        end

        b = new_class extends: a

        a.woot = 123
        assert_equal 123, b.woot
    end

    test "overridden value" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited :woot
        end

        b = new_class extends: a

        a.woot = 123
        b.woot = 456
        assert_equal 123, a.woot
        assert_equal 456, b.woot
    end

    test "empty hash" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited_hash :woot
        end

        assert_equal({}, a.woot)
    end

    test "default hash" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited_hash(:woot) { {abc: 123} }
        end

        assert_equal({abc: 123}, a.woot)
    end

    test "assigned hash" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited_hash :woot
        end

        a.woot[:abc] = 123
        assert_equal({abc: 123}, a.woot)
    end

    test "inherited hash" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited_hash :woot
        end

        b = new_class extends: a

        a.woot[:abc] = 123
        assert_equal({abc: 123}, b.woot)
    end

    test "inherited hash with merged values" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited_hash :woot
        end

        b = new_class extends: a

        a.woot[:abc] = 123
        b.woot[:def] = 456
        assert_equal({abc: 123}, a.woot)
        assert_equal({abc: 123, def: 456}, b.woot)
    end

    test "inherited hash with overridden value" do
        a = new_class do
            include InheritedAttributes
            mattr_inherited_hash :woot
        end

        b = new_class extends: a

        a.woot[:abc] = 123
        b.woot[:abc] = 456
        assert_equal({abc: 123}, a.woot)
        assert_equal({abc: 456}, b.woot)
    end
end
