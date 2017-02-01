require 'test_helper'

module Api
    class SessionsControllerTest < ActionController::TestCase
        include ModelControllerFindTest

        tests SessionsController

        test "start a session" do
            Timecop.freeze do
                user = create(:user)
                server = create(:server)

                post :start, player_id: user.player_id, server_id: server.id, ip: 123

                assert_json_response
                assert_exists server.sessions.user(user).online
                assert_now server.sessions.user(user).one.start
            end
        end

        test "finish a session" do
            Timecop.freeze do
                user = create(:user)
                server = create(:server)
                session = Session.start!(user: user, server: server, ip: 123)

                post :finish, id: session.id

                assert_json_response
                refute_exists user.sessions.server(server).online
                assert_now session.reload.end
            end
        end

        test "restart a session" do
            Timecop.freeze do
                user = create(:user)
                server = create(:server)
                previous_session = Session.start!(user: user, server: server, ip: 123)

                post :start,
                     player_id: user.player_id,
                     server_id: server.id,
                     ip: 123,
                     previous_session_id: previous_session.id

                assert_json_response
                assert_now previous_session.reload.end
                assert_exists server.sessions.user(user).online
            end
        end
    end
end
