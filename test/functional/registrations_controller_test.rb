require 'test_helper'

class RegistrationsControllerTest < ActionController::TestCase
    setup do
        @request.env['devise.mapping'] = Devise.mappings[:user]
    end

    test "start a new registration" do
        # User visits the registration page and gets a random register_token
        get :new

        assert_response :success
        assert_select '#token', text: /[0-9a-z]{12}\.register\.oc\.tc/
    end

    test "send email confirmation" do
        # Registration page polls and finds a user who connected with the register_token
        user = create(:unregistered_user)
        email = 'woot@donk.com'
        token = User.generate_register_token
        user.claim_register_token(token)

        post :create, email: email, token: token

        assert_json_response success: true, email_result: :available, username: user.username

        user.reload
        assert_nil user.register_token
        assert_nil user.email
        assert_equal email, user.unconfirmed_email

        assert_email_sent to: email , body: /#{user.username}/
    end

    test "authenticate with key" do
        user = create(:user)
        group = create(:group, permissions: [TokenAuthenticatable::KEY_PERMISSION])
        user.join_group(group)

        request_header(TokenAuthenticatable::KEY_HEADER => user.generate_api_key!)
        get :edit
        assert_response 200
    end

    test "authenticate with key requires permission" do
        user = create(:user)

        request_header(TokenAuthenticatable::KEY_HEADER => user.generate_api_key!(check_access: false))
        get :edit
        assert_response 403
    end

    test "authenticate with key does not require password permission" do
        user = create(:user)
        group = create(:group, permissions: [TokenAuthenticatable::KEY_PERMISSION,
                                             ['site', 'login', false]])
        user.join_group(group)

        request_header(TokenAuthenticatable::KEY_HEADER => user.generate_api_key!)
        get :edit
        assert_response 200
    end
end
