require 'test_helper'

module Admin
    class MembersControllerTest < ActionController::TestCase
        include AdminControllerTestHelper

        setup do
            @user = create(:user)
            @group = create(:group)
        end

        test "join group" do
            post :create, group_id: @group.id, membership: { user: @user.username }

            assert_response :redirect
            assert @user.reload.in_group?(@group), "user joined group"
        end

        test "leave group" do
            @user.join_group(@group)
            delete :destroy, group_id: @group.id, id: @user.player_id

            assert_response :redirect
            refute @user.reload.in_group?(@group)
        end
    end
end
