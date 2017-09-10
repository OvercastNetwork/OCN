module Api
    class DeathsController < ModelController
        controller_for Death

        def after_update(death)
            if death.raindrops && death.raindrops != 0 and user = death.killer_obj
                user.credit_tokens('raindrops', death.raindrops)
            end
        end
    end
end
