require 'test_helper'

class GroupTest < ActiveSupport::TestCase

    class User
        include Group::Member
    end

    setup do
        @group = create(:group)
        @user = User.create!
    end

    test "not in a group" do
        refute @user.in_group?(@group)
    end

    test "join a group" do
        @user.join_group(@group)
        assert @user.in_group?(@group)
        assert_set [@user], User.in_group(@group)
    end

    test "leave a group" do
        @user.join_group(@group)
        @user.leave_group(@group)
        refute @user.in_group?(@group)
        assert_set [], User.in_group(@group)
    end

    test "postpone group membership" do
        @user.join_group(@group, start: 1.day.from_now)
        refute @user.in_group?(@group)

        Timecop.freeze(2.days) do
            assert @user.in_group?(@group)
        end
    end

    test "expire group membership" do
        @user.join_group(@group, stop: 1.day.from_now)
        assert @user.in_group?(@group)

        Timecop.freeze(2.days) do
            refute @user.in_group?(@group)
        end
    end

    test "replace group membership" do
        @user.join_group(@group)
        assert @user.in_group?(@group)

        @user.join_group(@group, start: 1.day.from_now)
        refute @user.in_group?(@group)

        @user.join_group(@group, start: 1.day.ago)
        assert @user.in_group?(@group)
    end

    MEMBERSHIP_CASES = %w{
        never_join
        permanent
        temporary
        joined_yesterday
        join_tomorrow
        left_yesterday
        leave_tomorrow
    }.map(&:to_sym)

    # Create group memberships for the cases listed above. For each
    # parameter, pass a hash of users/groups to create a membership
    # for each one, or an empty hash with single user/group as the
    # default to use that thing for all cases.
    def join_test_groups(users, groups)
        users[:permanent]       .join_group(groups[:permanent])
        users[:temporary]       .join_group(groups[:temporary],         start: 1.day.ago,   stop: 1.day.from_now)
        users[:joined_yesterday].join_group(groups[:joined_yesterday],  start: 1.day.ago)
        users[:join_tomorrow]   .join_group(groups[:join_tomorrow],     start: 1.day.from_now)
        users[:left_yesterday]  .join_group(groups[:left_yesterday],                        stop: 1.day.ago)
        users[:leave_tomorrow]  .join_group(groups[:leave_tomorrow],                        stop: 1.day.from_now)
    end

    def assert_user_in_groups(user, groups)
        assert_set groups, user.active_groups
        assert_set groups, Group.with_member(user)

        groups.each do |group|
            assert user.in_group? group
        end
    end

    def assert_group_members(group, users)
        assert_set users, User.in_group(group)

        users.each do |user|
            assert user.in_group? group
        end
    end

    test "get groups for a user" do
        groups = Hash[*MEMBERSHIP_CASES.flat_map{|m| [m, create(:group, name: m.to_s)] }]
        join_test_groups(Hash.new(@user), groups)

        assert_user_in_groups @user, groups.values_at(:permanent, :temporary, :joined_yesterday, :leave_tomorrow)
    end

    test "get members of a group" do
        users = MEMBERSHIP_CASES.mash{|m| [m, User.create!] }
        join_test_groups(users, Hash.new(@group))

        assert_group_members @group, users.values_at(:permanent, :temporary, :joined_yesterday, :leave_tomorrow)
    end

    test "get expiration time" do
        @user.join_group(@group)
        assert_equal Time::INF_FUTURE, @group.expires(@user)

        expiry = Time.new(2099)
        @user.join_group(@group, stop: expiry)
        assert_equal expiry.utc, @group.expires(@user).utc
    end

    test "groups sorted by priority" do
        one     = create(:group, priority: 10)
        two     = create(:group, priority: 20)
        three   = create(:group, priority: 30)

        # Join groups out of order
        @user.join_group(three)
        @user.join_group(one)
        @user.join_group(two)

        assert_sequence [one, two, three],
                        @user.active_groups
    end

    test "get default group" do
        group = Group.default_group
        assert_equal '_default', group.name
        assert_equal group, Group.default_group
    end

    test "inherit permission from default group" do
        Group.default_group.web_permissions = {'site' => {'login' => true}}
        assert create(:user).has_permission?('site', 'login', true)
    end

    test "soft-delete group makes memberships inactive" do
        user = create(:user)
        group = create(:group)
        user.join_group(group)
        group.die!
        user.reload

        refute user.in_group? group
        refute user.active_groups.include? group
    end

    test "soft-delete group does not invalidate membership documents" do
        user = create(:user)
        group = create(:group)
        user.join_group(group)
        group.die!
        user.reload

        assert_valid user
        assert_valid user.memberships.first
    end
end
