class User
    module Teams
        extend ActiveSupport::Concern

        def has_team?
            !self.team.nil?
        end

        def team
            Team.with_member(self, true).first
        end

        def team_invites
            Team.with_member(self, false)
        end

        def clear_team_invites
            cleared = 0
            self.team_invites.each do |team|
                team.remove_member(self.username)
                cleared += 1 if team.save
            end
            cleared
        end
    end # Teams
end
