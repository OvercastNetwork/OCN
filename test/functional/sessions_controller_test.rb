require 'test_helper'

class SessionsControllerTest < ActionController::TestCase
    tests Devise::SessionsController

    setup do
        @request.env['devise.mapping'] = Devise.mappings[:user]
    end

    test "authenticate with password" do
        user = create(:user, password: 'password')

        post :create, user: {email: user.email, password: 'password'}
        assert_redirected_to '/'
    end

    test "authenticate with password requires permission" do
        user = create(:user, password: 'password')
        nologin = create(:group, permissions: [['site', 'login', false]])
        user.join_group(nologin)

        post :create, user: {email: user.email, password: 'password'}
        assert_response 200
    end
end
