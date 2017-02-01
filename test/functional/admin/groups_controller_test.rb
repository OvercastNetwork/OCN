require 'test_helper'

module Admin
    class GroupsControllerTest < ActionController::TestCase
        include AdminControllerTestHelper

        test "list all groups" do
            # Create out of order
            third  = create(:group, priority: 30)
            first  = create(:group, priority: 10)
            second = create(:group, priority: 20)

            get :index

            assert_response :success

            assert_assigns :groups
            assert_sequence [first, second, third],
                            assigns[:groups].reject(&:magic?)

            [first, second, third].each do |group|
                assert_select('.group-row', text: /#{group.name}/) do
                    assert_select('.group-priority',    text: /#{group.priority}/)
                    assert_select('.group-name',        text: /#{group.name}/)
                end
            end
        end
    end
end
