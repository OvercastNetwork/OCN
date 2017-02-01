module Api
    class WhispersController < ModelController
        controller_for Whisper

        def reply
            if whisper = Whisper.for_reply(model_param(User, :user_id))
                respond whisper.api_document
            else
                not_found
            end
        end
    end
end
