require 'test_helper'

class PunishmentsControllerTest < ActionController::TestCase
    setup do
        sign_in create(:user, admin: true)
    end

    test "list punishments" do
        ban = create(:ban)

        get :index

        assert_select "#punishment_#{ban.id}" do
            assert_select '.type', text: /Ban/
            assert_select '.punished', text: /#{ban.punished.username}/
            assert_select '.punisher', text: /#{ban.punisher.username}/
        end
    end

    test "filter by punisher" do
        kick = create(:kick)
        ban = create(:ban)

        get :index, punisher: kick.punisher.username

        assert_select "#punishment_#{kick.id}" do
            assert_select '.punisher', text: /#{kick.punisher.username}/
            refute_select '.punisher', text: /#{ban.punisher.username}/
        end
    end

    test "view punishment" do
        ban = create(:ban)

        get :show, id: ban

        assert_select '.punished', text: /#{ban.punished.username}/
        assert_select '.punisher', text: /#{ban.punisher.username}/
        assert_select '.punishment-type', text: /ban/i
    end

    test "edit punishment" do
        ban = create(:ban)

        get :edit, id: ban

        assert_response(:success)
    end

    test "save punishment" do
        ban = create(:ban)
        user = create(:user)

        post :update, id: ban, punishment: {punished: user,
                                            punisher: ban.punisher}

        assert_response(:redirect)
        assert_equal user, ban.reload.punished
    end
end
