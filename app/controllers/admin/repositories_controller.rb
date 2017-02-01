module Admin
    class RepositoriesController < BaseController

        respond_to :json

        before_filter :find_repo

        def build
            branch = required_param(:branch)
            dry = boolean_param(:dry, default: true)

            out = Logging.capture do |logger|
                logger.info "Building repository '#{@repo.title}', branch '#{branch}'#{" (dry run)" if dry}"
                logger.info '-' * 80
                success = @repo.local_build!(branch: branch, dry: dry)
            end

            render status: success ? 200 : 422, text: out
        end

        protected

        def find_repo
            unless @repo = Repository[required_param(:id)]
                render status: 404, text: "Unknown repository"
            end
        end
    end
end
