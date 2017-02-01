require 'test_helper'

class ServerTest < ActiveSupport::TestCase
    test "startup" do
        Timecop.freeze do
            server = create(:server)
            server.plugin_versions = {"plugin" => "version"}
            server.online = true
            server.save!

            assert server.online?
            assert_same_time Time.now, server.start_time
            assert_equal "version", server.plugin_versions["plugin"]
        end
    end

    test "shutdown" do
        Timecop.freeze do
            server = create(:server)
            server.online = true
            server.save!
            server.online = false
            server.save!

            refute server.online?
            assert_same_time Time.now, server.stop_time
        end
    end

    test "box validation" do
        server = create(:server)

        server.datacenter = 'US'
        server.box_id = 'chi01'
        assert_valid server
        server.box_id = 'ams01'
        refute_valid server

        server.datacenter = 'EU'
        server.box_id = 'chi01'
        refute_valid server
        server.box_id = 'ams01'
        assert_valid server

        server.datacenter = 'TM'
        server.box_id = 'chi01'
        assert_valid server
        server.box_id = 'ams01'
        refute_valid server

        server.box_id = 'woot'
        assert_valid server
    end
end
