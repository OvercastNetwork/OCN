module Admin
    class DataController < BaseController
        include JsonController

        def validate
            success = false
            out = Logging.capture do
                success = Buildable.load_models(store: make_store(params[:files]), dry: true)
            end

            render status: success ? 200 : 422, text: out
        end

        def pull
            files = {}
            log = Logging.capture do
                Buildable.save_models(store: make_store(files), dry: false)
            end
            respond files: files, log: log
        end

        def permissions
            render text: Permissions.pretty_permissions, content_type: 'text/plain'
        end

        protected

        def make_store(files = {})
            Buildable::Store::Memory.new(files)
        end
    end
end
