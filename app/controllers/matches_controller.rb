class MatchesController < ApplicationController
    def index
        @servers = Server.pgms.portals(Portal.listed).visible_to_public.asc(:name, :datacenter)
        @server = model_param(@servers, :server_id)

        @matches = Match.loaded_or_played.recent.desc(:load)
        if @server
            @matches = @matches.where(server_id: @server.id)
        else
            @matches = @matches.in(server_id: @servers.map(&:id))
        end
        @matches = a_page_of(@matches)
    end

    def show
        @match = model_param(Match)
        @teams = Hash.default{ {} }
        participants = {}

        @match.participations.asc(:start).join_users_and_sessions.each do |partic|
            if partic.user && (!partic.session || !partic.session.disguised_to? || partic.start < partic.user.last_seen_by)
                @teams[partic.team_display_name][partic.user] = partic
                participants[partic.user] = partic
            end
        end

        @teams['Observers'] ||= @teams['Spectators'] || {}
        @teams.delete('Spectators')

        # If a player played, remove them from the observers
        @teams['Observers'].reject!{|user, _| participants[user] }

        if @match.end? && @match.winning_teams.size == 1
            @winning_team_name = @match.winning_teams[0].name
        end

        # Find deaths, kills, and the most common weapon
        @death_count = 0
        @kill_count = 0
        @weapons = Hash.default(0)

        @match.deaths.each do |death|
            @death_count += 1
            @kill_count += 1 if death.killer_id?

            # Special Cases
            death.weapon = "BOW" if death.cause == "ARROW"
            death.weapon = "TNT" if death.cause == "BLOCK_EXPLOSION"

            @weapons[death.weapon] += 1 if death.weapon
        end

        unless @weapons.empty?
            @most_common = @weapons.max_by{|_, v| v}[0]
            @least_common = @weapons.min_by{|_, v| v}[0]
        end

        @some_valid = @match.engagements.ignored(false).exists?
        @some_invalid = @match.engagements.ignored(true).exists?
    end

    def validate
        return not_found unless current_user.has_permission?('match', 'validate', true)

        valid = required_param(:valid).parse_bool
        match = model_param(Match)

        match.set_valid!(valid)
        redirect_to_back
    end
end
