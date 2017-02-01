require 'test_helper'

module Api
    class ServersControllerTest < ActionController::TestCase
        include ApiControllerTest

        tests ServersController

        test "list servers" do
            server = create(:server, online: true, startup_visibility: Server::Visibility::PUBLIC)

            post :search, datacenter: server.datacenter, families: [server.family]

            assert_json_collection documents: [server.reload.api_status_document]
        end

        test "show server" do
            server = create(:server)

            get :show, id: server

            assert_json_response server.reload.api_document
        end

        test "find server by name" do
            server = create(:server, name: "Woot")

            get :by_name, name_search: "woot"

            assert_json_response
            assert_equal server.name, @json_response['documents'][0]['name']
            assert_equal server.bungee_name, @json_response['documents'][0]['bungee_name']
        end
    end
end
