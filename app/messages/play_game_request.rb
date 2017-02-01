# Request to play a given Game. The API will reply with a PlayGameResponse.
#
# The game field is a search string that may be directly typed by the player,
# or nil if the player wants to leave the game they are currently playing.
class PlayGameRequest < BaseMessage
    field :user_id
    field :arena_id

    def user
        User.need(user_id)
    end

    def arena
        arena_id && Arena.need(arena_id)
    end
end
