class User
    module Punishments
        extend ActiveSupport::Concern

        def is_banned?
            is_in_game_banned? || is_forum_banned?
        end

        def is_in_game_banned?
            Punishment.banned?(self)
        end

        def is_permanently_in_game_banned?
            Punichment.permanently_banned?(self)
        end

        def is_forum_banned?
            Punishment.forum_banned?(self)
        end

        def is_tourney_banned?
            Punishment.tourney_banned?(self)
        end
    end # Punishments
end
