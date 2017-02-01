require 'test_helper'

class StaffControllerTest < ActionController::TestCase
    test "view staff page" do
        groups = 3.times.map do
            group = create(:group, staff: true)
            3.times do
                create(:user).join_group(group)
            end
            group
        end

        get :index

        assert_response :success

        groups.each do |group|
            assert_select('.staff-group', count: 1, text: /#{group.name}/)
            User.in_group(group).each do |member|
                assert_select('.staff-username', count: 1, text: /#{member.username}/)
            end
        end
    end

    test "staff only" do
        staff_group = create(:group, name: 'Staff Group', staff: true)
        normal_group = create(:group, name: 'Normal Group', staff: false)
        create(:user).join_group(staff_group).join_group(normal_group)

        get :index

        assert_select('.staff-group', text: /#{staff_group.name}/)
        refute_select('.staff-group', text: /#{normal_group.name}/)
    end

    test "username collisions rerouted" do
        create(:user, username: 'staff').join_group(create(:group, staff: true))

        get :index

        refute_select("a:match('href', ?)", %r[/staff])
        assert_select("a:match('href', ?)", %r[/users/staff], count: 1)
    end
end
