class PlayController < ApplicationController
    before_filter :find_server

    def index
        portals = [*(@portal || Portal.listed)]
        @servers = Server
            .online
            .pgms
            .visible_to_public
            .portals(portals)
            .or({game_id: nil}, {num_participating: {$gt => 0}})
            .prefetch('current_match.map', 'next_map')
            .select{|s| s.current_match && s.current_match.map }

        @sessions = Session.online.in(server_id: @servers.map(&:id)).left_join_users
        @servers = Server.left_join_sessions(@sessions, servers: @servers)
        @servers.sort_by!{|s| -s.joined_sessions.size }

        all_friends = Set.new(current_user_safe.friends)
        @friends = @sessions.select{|s| all_friends.include? s.player }.group_by(&:server)

        realms = @servers.flat_map(&:realms).uniq
        @staff = @sessions.select{|s| s.player.is_mc_staff?(realms) }.group_by(&:server)

        @portal_infos = portals.map do |portal|
            servers = @servers.select{|s| s.portal == portal }
            {
                portal: portal,
                servers: servers.size,
                players: Server.bungees.online.portal(portal).sum(&:num_online)
            }
        end
    end

    def teleport
        if current_user && @server
            current_user.teleport_to(@server)
        end

        redirect_to play_path
    end

    private

    def find_server
        if params[:portal]
            @portal = Portal.listed.find{|p| p.id.to_s.downcase == params[:portal].to_s.downcase }

            if @portal && params[:server]
                @server = Server.pgms.visible_to_public.portal(@portal).find_by_name(params[:server])
            end
        end
        @global = !@portal
    end
end
