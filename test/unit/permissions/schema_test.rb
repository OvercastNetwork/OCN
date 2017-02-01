require 'test_helper'
require 'unit/permissions/holder'

class SchemaTest < ActiveSupport::TestCase

    def schema
        Holder.permission_schema
    end

    test "stringifies" do
        assert_equal ['woot', 'donk', true], schema.expand_without_assert(:woot, :donk, true)
    end

    test "flattens" do
        assert_equal ['woot', 'donk', true], schema.expand_without_assert(['woot', 'donk'], true)
    end

    test "splits dotted" do
        assert_equal ['woot', 'donk', true], schema.expand_without_assert('woot.donk', true)
    end

    test "converts documents to their id" do
        doc = new_model.create!
        assert_equal [doc.id.to_s], schema.expand_without_assert(doc)
    end

    test "checks existence" do
        assert_raises ArgumentError do
            schema.expand(:perm, :that, :doesnt, :exist)
        end
    end
end
