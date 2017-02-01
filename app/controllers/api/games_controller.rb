module Api
    class GamesController < ModelController
        controller_for Game

        def model_criteria
            super.visible.asc(:priority)
        end
    end
end
