module Api
    class TournamentsController < ModelController
        controller_for Tournament

        def teams
            respond documents: model_instance.accepted_teams.map(&:api_identity_document)
        end

        def entrants
            team = if team_id = params[:team_id]
                Team.find(team_id)
            elsif team_name = params[:team_name]
                Team.by_name(team_name)
            elsif member_id = params[:member_id] and user = User.find(member_id)
                user.team
            end

            if team and entrant = model_instance.entrant_for(team)
                respond entrant.api_document
            else
                raise NotFound
            end
        end

        def record_match
            match = model_param(Match, :match_id)
            entrants = model_instance.record_match(match)

            respond match: match.api_document,
                    entrants: entrants.map(&:api_document)
        end
    end
end
