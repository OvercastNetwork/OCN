require 'test_helper'
require 'unit/permissions/holder'

class HolderTest < ActiveSupport::TestCase

    test "get root tree" do
        tree = {woot: {donk: true}}
        dude = Holder.new(permissions: tree)

        assert_equal tree, dude.permission_subtree
    end

    test "get subtree" do
        tree = {woot: {donk: true}}
        dude = Holder.new(permissions: tree)

        assert_equal tree[:woot], dude.permission_subtree(:woot)
        assert_equal tree[:woot], dude.permission_subtree('woot')
        assert dude.permission_subtree(:woot, :donk)
    end

    test "held permission" do
        dude = Holder.new(permissions: {woot: {donk: true}})
        assert dude.has_permission?(:woot, :donk, true)
        dude.assert_permission(:woot, :donk, true)
    end

    test "unheld permission" do
        dude = Holder.new
        refute dude.has_permission?(:woot, :donk, true)
        assert_raises Permissions::Denied do
            dude.assert_permission(:woot, :donk, true)
        end
    end

    test "everybody permission" do
        dude = Holder.new
        assert dude.has_permission?(Permissions.everybody_permission)
        dude.assert_permission(Permissions.everybody_permission)
    end

    test "admin has all" do
        dude = Holder.new(admin: true)
        assert dude.has_permission?(:woot, :donk, true)
        dude.assert_permission(:woot, :donk, true)
    end
end
