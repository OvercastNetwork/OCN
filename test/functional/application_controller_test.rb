require 'test_helper'

class ApplicationControllerTest < ActionController::TestCase
    test "view root as anonymous" do
        get :index
        assert_response :success
    end

    test "view root" do
        sign_in(create(:user))
        get :index
        assert_response :success
    end
end
