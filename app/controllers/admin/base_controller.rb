module Admin
    class BaseController < ApplicationController
        include Breadcrumbs

        layout 'admin'

        class << self
            def breadcrumb_trail
                if self == BaseController
                    [["Admin", Rails.application.routes.url_helpers.admin_root_path]]
                else
                    super
                end
            end

            def general_permission
                ['site', 'admin', true]
            end
        end

        before_filter :authenticate_admin

        def index
            authenticate_admin
        end

        def test_error
            raise params[:message] || "Test Error"
        rescue => ex
            # Make sure the error goes to Sentry, even in development env
            Raven.capture_exception(ex)
            raise
        end

        private

        def authenticate_admin
            return not_found unless forem_user && user_is_admin?
        end
    end
end
