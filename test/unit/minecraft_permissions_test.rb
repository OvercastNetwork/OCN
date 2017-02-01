require 'test_helper'

class MinecraftPermissionsTest < ActiveSupport::TestCase
    test "add minecraft permissions" do
        group = create(:group, minecraft_permissions: {'global' => ['a', 'b'] })
        perms = group.merge_mc_permissions({}, ['global'])

        assert_equal({'a' => true, 'b' => true}, perms)
    end

    test "remove minecraft permissions" do
        group = create(:group, minecraft_permissions: {'global' => ['a', '-b'] })
        perms = group.merge_mc_permissions({'a' => true, 'b' => true, 'c' => true}, ['global'])

        assert_equal({'a' => true, 'b' => false, 'c' => true}, perms)
    end

    test "add permissions in multiple realms" do
        group = create(:group, minecraft_permissions: {'realm1' => ['a'], 'realm2' => ['b'] })

        assert_equal({'a' => true}, group.merge_mc_permissions({}, ['realm1']))
        assert_equal({'b' => true}, group.merge_mc_permissions({}, ['realm2']))
        assert_equal({'a' => true, 'b' => true}, group.merge_mc_permissions({}, ['realm1', 'realm2']))
    end

    test "permission realms applied in order" do
        group = create(:group, minecraft_permissions: {'realm1' => ['a', '-b'], 'realm2' => ['b', '-a'] })

        assert_equal({'a' => false, 'b' => true}, group.merge_mc_permissions({}, ['realm1', 'realm2']))
        assert_equal({'a' => true, 'b' => false}, group.merge_mc_permissions({}, ['realm2', 'realm1']))
    end

    test "user implicitly gets minecraft permissions from default group" do
        create(:default_group, minecraft_permissions: {'global' => ['a', 'b'] })
        user = create(:user)

        assert_equal({'a' => true, 'b' => true}, user.mc_permissions(['global']))
    end

    test "user gets minecraft permissions from joined group" do
        create(:default_group, minecraft_permissions: {'global' => ['a'] })
        group = create(:group, minecraft_permissions: {'global' => ['b'] })
        user = create(:user)
        user.join_group(group)

        assert_equal({'a' => true, 'b' => true}, user.mc_permissions(['global']))
    end

    test "joined group removes minecraft permission from default group" do
        create(:default_group, minecraft_permissions: {'global' => ['a', 'b'] })
        group = create(:group, minecraft_permissions: {'global' => ['a', '-b'] })
        user = create(:user)
        user.join_group(group)

        assert_equal({'a' => true, 'b' => false}, user.mc_permissions(['global']))
    end

    test "groups apply minecraft permissions in priority order" do
        group1 = create(:group, priority: 1, minecraft_permissions: {'global' => ['a', '-b'] })
        group2 = create(:group, priority: 2, minecraft_permissions: {'global' => ['-a', 'b'] })
        user = create(:user)
        user.join_group(group2)
        user.join_group(group1)

        assert_equal({'a' => true, 'b' => false}, user.mc_permissions(['global']))

        group1.update_attributes!(priority: 3)

        assert_equal({'a' => false, 'b' => true}, user.reload.mc_permissions(['global']))
    end

    test "group with package is premium group" do
        group = create(:group)
        create(:package, group: group)

        assert group.premium?
    end

    test "decode minecraft permissions" do
        assert_equal({'yes' => true, 'no' => false, 'def' => true},
                     Group.decode_mc_permissions(['+yes', '-no', 'def']))
    end
end
