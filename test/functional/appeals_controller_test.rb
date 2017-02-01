require 'test_helper'

class AppealsControllerTest < ActionController::TestCase
    setup do
        sign_in create(:user, admin: true)
    end

    test "list appeals" do
        appeal = create(:appeal)

        get :index

        assert_select "#appeal_#{appeal.id}" do
            assert_select '.status', text: /#{appeal.status}/
            assert_select '.punished', text: /#{appeal.punished.username}/
        end
    end

    test "show appeal" do
        appeal = create(:appeal)

        get :show, id: appeal

        assert_select "#appeal_excuse_#{appeal.excuses[0].id}" do
            assert_select '.punisher', text: /#{appeal.excuses[0].punisher.username}/
            assert_select '.punished', text: /#{appeal.excuses[0].punishment.punished.username}/
            assert_select '.punishment-reason', text: /#{appeal.excuses[0].punishment.reason}/
            assert_select '.appeal-reason', text: /#{appeal.excuses[0].reason}/
        end
    end
end
