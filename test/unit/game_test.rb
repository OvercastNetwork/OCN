require 'test_helper'

class GameTest < ActiveSupport::TestCase

    test "name search" do
        game = create(:game, name: "Big Fun")
        assert_equal game, Game.by_name('Big Fun')
        assert_equal game, Game.by_name(' BigFun ')
        assert_equal game, Game.by_name('bigfun')
        assert_equal game, Game.by_name('BIGFUN')
        assert_nil Game.by_name('smallfun')
    end

    test "queued with no servers" do
        user = create(:user)
        arena = create(:arena)

        arena.enqueue!(user)

        assert ticket = arena.tickets_queued.first
        assert_equal user, ticket.user
        assert_nil ticket.server
        assert_nil ticket.dispatched_at
    end

    test "queued with insufficient players for empty server" do
        server = create(:game_server, min_players: 2)
        user = create(:user)

        server.arena.enqueue!(user)

        refute_nil user.ticket
        assert_member server.arena.tickets_queued, user.ticket
    end

    test "provision empty server" do
        server = create(:game_server, min_players: 1)
        user = create(:user)

        server.arena.enqueue!(user)

        assert_empty server.arena.tickets_queued
        refute_nil user.ticket
        assert_equal server, user.ticket.server
        assert_now user.ticket.dispatched_at
    end

    test "join partly full server" do
        server = create(:game_server, min_players: 1, max_players: 2)
        playing = create(:user)
        server.tickets.create!(user: playing, arena: server.arena)

        joining = create(:user)
        server.arena.enqueue!(joining)

        assert_size 2, server.tickets
    end

    test "queued with full server" do
        playing = create(:user)
        server = create(:game_server, max_players: 1)
        server.tickets.create!(user: playing, arena: server.arena)

        joining = create(:user)
        server.arena.enqueue!(joining)

        refute_nil ticket = server.arena.tickets_queued.first
        assert_equal joining, ticket.user
    end

    test "requeue" do
        server = create(:game_server)
        playing = create(:user)
        ticket = server.tickets.create!(user: playing, arena: server.arena)

        assert_equal server, ticket.server
        ticket.requeue!
        assert_nil ticket.reload.server
    end

    test "empty server" do
        server = create(:game_server, min_players: 4)
        3.times.map do
            server.tickets.create!(user: create(:user), arena: server.arena)
        end

        assert_empty server.arena.tickets_queued

        server.requeue_participants!
        assert_empty server.tickets
        assert_size 3, server.arena.tickets_queued
    end
end
