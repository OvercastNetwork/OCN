require 'test_helper'

class SessionTest < ActiveSupport::TestCase

    setup do
        @server = create(:server)

        @user = create(:user)
        @stranger = create(:user)
        @friend = create(:friend, of: @user)

        @reveal_group = create(:group, minecraft_permissions: {'global' => [User::Nickname::REVEAL_ALL_PERMISSION]})
        @staff = create(:user)
        @staff.join_group(@reveal_group)
    end

    def assert_sighting(sighting, online: nil, time: nil, server: nil, session: nil)
        if online == true
            assert sighting.online?
        elsif online == false
            refute sighting.online?
        end

        if time
            assert_same_time time, sighting.time
        else
            assert_now sighting.time
        end

        assert_equal server, sighting.server if server
        assert_equal session, sighting.session if session
    end

    test "start session" do
        session = Session.start!(user: @user, server: @server, ip: 123)
        @user.reload

        assert session.online?, "session should be active"
        assert_now session.start
        assert_nil session.end
        assert_equal @user, session.player
        assert_equal @server, session.server
        assert_equal @server.family, session.family
        assert_equal 123, session.ip

        assert_sighting @user.last_sighting, online: true, server: @server, session: session
        assert_sighting @user.last_public_sighting, online: true, server: @server, session: session

        Timecop.freeze(1.minute)

        assert_now @user.last_seen_by(@stranger)
        assert_now @user.last_seen_by(@friend)
        assert_now @user.last_seen_by(@staff)
    end

    test "finish session" do
        session = Session.start!(user: @user, server: @server, ip: 123)
        session.finish!
        @user.reload

        refute session.online?, "session should be inactive"
        assert_now session.end

        assert_sighting @user.last_sighting, online: false, server: @server, session: session
        assert_sighting @user.last_public_sighting, online: false, server: @server, session: session

        Timecop.freeze(1.minute)

        assert_same_time 1.minute.ago, @user.last_seen_by(@stranger)
        assert_same_time 1.minute.ago, @user.last_seen_by(@friend)
        assert_same_time 1.minute.ago, @user.last_seen_by(@staff)
    end

    test "restart session" do
        session1 = Session.start!(user: @user, server: create(:server), ip: 123)

        Timecop.freeze(1.minute)

        session1.finish!
        session2 = Session.start!(user: @user, server: @server, ip: 123)
        @user.reload

        assert_sighting @user.last_sighting, online: true, server: @server, session: session2
        assert_sighting @user.last_public_sighting, online: true, server: @server, session: session2
    end

    test "overlapping sessions" do
        session1 = Session.start!(user: @user, server: create(:server), ip: 123)

        Timecop.freeze(1.minute)

        session2 = Session.start!(user: @user, server: @server, ip: 123)
        session1.finish!
        @user.reload

        assert_sighting @user.last_sighting, online: true, server: @server, session: session2
        assert_sighting @user.last_public_sighting, online: true, server: @server, session: session2
    end

    test "never seen" do
        assert_never @user.last_seen_by(@stranger)
        assert_never @user.last_seen_by(@friend)
        assert_never @user.last_seen_by(@staff)
    end

    test "start nicked session" do
        @user.nickname = "Nickname"
        @user.save
        session = Session.start!(user: @user, server: @server, ip: 123)
        @user.reload

        assert_equal @user.nickname, session.nickname
        assert_equal @user.nickname_lower, session.nickname_lower

        assert_sighting @user.last_sighting, online: true, server: @server, session: session
        assert_nil @user.last_public_sighting

        assert_never @user.last_seen_by(@stranger)
        assert_now @user.last_seen_by(@friend)
        assert_now @user.last_seen_by(@staff)
    end

    test "set nickname" do
        normal_server = create(:server)
        normal_session = Session.start!(user: @user, server: normal_server, ip: 123)

        Timecop.freeze(1.minute)

        @user.nickname = "Nickname"
        @user.save!
        @user.reload

        nicked_server = create(:server)
        nicked_session = Session.start!(user: @user, server: nicked_server, ip: 123)
        normal_session.finish!
        @user.reload

        Timecop.freeze(1.minute)

        assert_sighting @user.last_sighting, online: true, time: 1.minute.ago, server: nicked_server, session: nicked_session
        assert_sighting @user.last_public_sighting, online: false, time: 1.minute.ago, server: normal_server, session: normal_session

        assert_same_time 1.minute.ago, @user.last_seen_by(@stranger)
        assert_now @user.last_seen_by(@friend)
        assert_now @user.last_seen_by(@staff)
    end

    test "set nickname immediate" do
        normal_session = Session.start!(user: @user, server: @server, ip: 123)

        Timecop.freeze(1.minute)

        @user.nickname = "Nickname"
        @user.save
        @user.reload

        normal_session.finish!
        nicked_session = Session.start!(user: @user, server: @server, ip: 123)
        @user.reload

        Timecop.freeze(1.minute)

        assert_sighting @user.last_sighting, online: true, time: 1.minute.ago, server: @server, session: nicked_session
        assert_sighting @user.last_public_sighting, online: false, time: 1.minute.ago, server: @server, session: normal_session

        assert_same_time 1.minute.ago, @user.last_seen_by(@stranger)
        assert_now @user.last_seen_by(@friend)
        assert_now @user.last_seen_by(@staff)
    end

    test "clear nickname" do
        @user.nickname = "Nickname"
        @user.save!
        nicked_server = create(:server)
        nicked_session = Session.start!(user: @user, server: nicked_server, ip: 123)
        @user.reload

        Timecop.freeze(1.minute)

        @user.nickname = nil
        @user.save!
        normal_server = create(:server)
        normal_session = Session.start!(user: @user, server: normal_server, ip: 123)
        nicked_session.finish!
        @user.reload

        Timecop.freeze(1.minute)

        assert_sighting @user.last_sighting, online: true, time: 1.minute.ago, server: normal_server, session: normal_session
        assert_sighting @user.last_public_sighting, online: true, time: 1.minute.ago, server: normal_server, session: normal_session

        assert_now @user.last_seen_by(@stranger)
        assert_now @user.last_seen_by(@friend)
        assert_now @user.last_seen_by(@staff)
    end
end
