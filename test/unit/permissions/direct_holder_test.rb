require 'test_helper'
require 'unit/permissions/holder'

class DirectHolderTest < ActiveSupport::TestCase
    class Model
        include Mongoid::Document
        include Permissions::DirectHolder

        def self.permission_schema
            Holder.permission_schema
        end
    end

    test "persists permissions" do
        Model.create!(web_permissions: {woot: {donk: true}})
        assert Model.first.has_permission?(:woot, :donk, true)
    end

    test "validates permissions" do
        doc = Model.new(web_permissions: {blah: {woot: true}})
        refute_valid doc, :web_permissions
    end

    test "permission query" do
        a = Model.create!(web_permissions: {woot: {donk: true}})
        Model.create!

        assert_equal [a], Model.with_permission(:woot, :donk, true).to_a
    end
end
