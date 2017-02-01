module Breadcrumbs
    extend ActiveSupport::Concern

    module CommonMethods
        def breadcrumb_name
            @breadcrumb_name || default_breadcrumb_name
        end

        def breadcrumb_path
            @breadcrumb_path || default_breadcrumb_path
        end

        def breadcrumb_node
            name = breadcrumb_name
            path = breadcrumb_path
            [name, path] if name && path
        end

        def breadcrumb(name = nil, path = nil)
            @breadcrumb_name = name if name
            @breadcrumb_path = path if path
        end

        def breadcrumb_trail
            [*breadcrumb_prefix, breadcrumb_node].compact
        end
    end

    module ClassMethods
        include CommonMethods

        def breadcrumb_prefix
            if superclass.respond_to?(:breadcrumb_trail)
                superclass.breadcrumb_trail
            else
                []
            end
        end

        def default_breadcrumb_name
            controller_name.humanize
        end

        def default_breadcrumb_path
            Rails.application.routes.url_helpers.url_for(controller: controller_path, only_path: true)
        end
    end

    include CommonMethods

    def breadcrumb_prefix
        if self.class.respond_to?(:breadcrumb_trail)
            self.class.breadcrumb_trail
        else
            []
        end
    end

    def default_breadcrumb_name
        action_name.humanize unless action_name == 'index'
    end

    def default_breadcrumb_path
        request.path
    end

    included do
        helper_method :breadcrumb_trail
    end
end
