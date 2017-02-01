require 'test_helper'

class UsersControllerTest < ActionController::TestCase
    test "view profile as anonymous" do
        user = create(:user)
        get :show, name: user.username
        assert_response :success
    end

    test "view profile" do
        sign_in(create(:user))
        user = create(:user)
        get :show, name: user.username
        assert_response :success
    end

    test "view own profile" do
        user = create(:user)
        sign_in(user)
        get :show, name: user.username
        assert_response :success
    end
end
