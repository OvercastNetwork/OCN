class Team
    module Alert
        class Base < ::Alert
            belongs_to :team, index: true
            validates_presence_of :team
            attr_accessible :team

            def link
                if team
                    Rails.application.routes.url_helpers.team_path(team)
                else
                    super
                end
            end
        end

        class Invite < Base
            def rich_message
                [{message: "You have been invited to join #{team.name}"}]
            end
        end

        class MemberAlert < Base
            belongs_to :member, class_name: 'User'
            validates_presence_of :member
            attr_accessible :member
        end

        class Decline < MemberAlert
            def rich_message
                [{user: member}, {message: " declined an invitation to #{team.name}"}]
            end
        end

        class Join < MemberAlert
            def rich_message
                [{user: member}, {message: " joined #{team.name}"}]
            end
        end

        class Leave < MemberAlert
            def rich_message
                if member == user
                    [{message: "You were removed from #{team.name}"}]
                else
                    [{user: member}, {message: " left #{team.name}"}]
                end
            end
        end

        class ChangeLeader < MemberAlert
            def rich_message
                if member == user
                    [{message: "You became the leader of #{team.name}"}]
                else
                    [{user: member}, {message: " became the leader of #{team.name}"}]
                end
            end
        end

        class TournamentAlert < Base
            belongs_to :tournament
            validates_presence_of :tournament
            attr_accessible :tournament

            def link
                Rails.application.routes.url_helpers.tournament_path(tournament.url)
            end
        end

        class Register < TournamentAlert
            def rich_message
                [{message: "#{team.name} is awaiting your confirmation for #{tournament.name}"}]
            end
        end

        class Unregister < TournamentAlert
            def rich_message
                [{message: "#{team.name} dropped out of #{tournament.name}"}]
            end
        end

        class Confirm < TournamentAlert
            belongs_to :member, class_name: 'User'
            validates_presence_of :member
            attr_accessible :member

            def rich_message
                [{user: member}, {message: " confirmed their participation in #{tournament.name}"}]
            end
        end

        class Accept < TournamentAlert
            def rich_message
                [{message: "#{team.name} was accepted to play in #{tournament.name}"}]
            end
        end

        class Reject < TournamentAlert
            def rich_message
                [{message: "#{team.name} was rejected from playing in #{tournament.name}"}]
            end
        end

        class Disband < Base
            def rich_message
                # Legacy instances of this alert have no team
                [{message: "#{if team then team.name else "Your team" end} was disbanded"}]
            end
        end
    end
end
