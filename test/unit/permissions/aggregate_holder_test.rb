require 'test_helper'
require 'unit/permissions/holder'

class AggregateHolderTest < ActiveSupport::TestCase
    class User
        include Permissions::AggregateHolder
        attr_accessor :instance_permission_groups

        def initialize(*groups)
            @instance_permission_groups = groups
        end

        def self.permission_schema
            Holder.permission_schema
        end
    end

    test "empty" do
        user = User.new
        refute user.has_permission?(:woot, :donk, true)
        refute user.admin?
        assert user.has_permission?(Permissions.everybody_permission)
    end

    test "in one group" do
        user = User.new(Holder.new(permissions: {woot: {donk: true}}))
        assert user.has_permission?(:woot, :donk, true)
        refute user.admin?
        assert user.has_permission?(Permissions.everybody_permission)
    end

    test "two groups with merged permissions" do
        user = User.new(
            Holder.new(permissions: {woot: {donk: true}}),
            Holder.new(permissions: {woot: {zing: :all}}),
        )
        assert user.has_permission?(:woot, :donk, true)
        assert user.has_permission?('woot.zing.all')
    end

    test "two groups with permission override" do
        user = User.new(
            Holder.new(permissions: {woot: {donk: false}}),
            Holder.new(permissions: {woot: {donk: true}}),
        )
        assert user.has_permission?(:woot, :donk, false)

        user = User.new(
            Holder.new(permissions: {woot: {donk: true}}),
            Holder.new(permissions: {woot: {donk: false}}),
        )
        assert user.has_permission?(:woot, :donk, true)
    end

    test "get perms from default group" do
        group = Holder.new(permissions: {woot: {donk: true}})

        user = new_class(extends: User) do
            define_singleton_method :permission_groups do
                [group]
            end
        end.new

        assert user.has_permission?(:woot, :donk, true)
    end
end
