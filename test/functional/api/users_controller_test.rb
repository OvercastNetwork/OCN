require 'test_helper'

module Api
    class UsersControllerTest < ActionController::TestCase
        include ModelControllerFindTest

        tests UsersController

        test "purchase gizmo" do
            user = create(:user, raindrops: 100)
            group = create(:gizmo, name: "woot")

            post :purchase_gizmo, id: user.player_id, gizmo_name: "woot", price: 25

            assert_response :success
            assert user.reload.in_group?(group)
            assert_equal 75, user.raindrops
        end

        test "purchase gizmo fails if already owned" do
            user = create(:user, raindrops: 100)
            group = create(:gizmo, name: "woot")
            user.join_group(group)

            post :purchase_gizmo, id: user.player_id, gizmo_name: "woot", price: 25

            assert_response 403
            assert_equal 100, user.reload.raindrops
        end

        test "purchase gizmo fails if too expensive" do
            user = create(:user, raindrops: 100)
            group = create(:gizmo, name: "woot")

            post :purchase_gizmo, id: user.player_id, gizmo_name: "woot", price: 101

            assert_response 403
            refute user.reload.in_group?(group)
            assert_equal 100, user.raindrops
        end

        test "login" do
            bungee = create(:bungee)
            user = create(:user)
            ip = '1.2.3.4'

            post :login, server_id: bungee.id, username: user.username, uuid: user.uuid, ip: ip


            json = assert_json_response message: nil, route_to_server: nil
            assert_equal user.api_player_id, json['user']['player']
            assert_equal ip, user.reload.mc_last_sign_in_ip
        end

        test "register" do
            bungee = create(:bungee)
            user = create(:unregistered_user)
            ip = '1.2.3.4'
            token = User.generate_register_token

            post :login, server_id: bungee.id, username: user.username, uuid: user.uuid, ip: ip, virtual_host: "#{token}.register.#{ORG::DOMAIN}"

            json = assert_json_response
            assert_not_nil json['message']
            assert_equal token, user.reload.register_token
        end
    end
end
