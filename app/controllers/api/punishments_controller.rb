module Api
    class PunishmentsController < ModelController
        controller_for Punishment

        def update
            attrs = document_param
            if attrs['off_record']
                # Broadcast but don't persist
                model_class.new(attrs).api_announce!
                respond 200
            else
                super
            end
        end
    end
end
