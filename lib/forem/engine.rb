module ::Forem
    class Engine < Rails::Engine
        isolate_namespace Forem

        class << self
            attr_accessor :root
            def root
                @root ||= Pathname.new(File.expand_path('../../', __FILE__))
            end

            def url_helpers
                instance.routes.url_helpers
            end
        end

        # Fix for #88
        config.to_prepare do
            # add forem helpers to main application
            ::ApplicationController.send :helper, Forem::Engine.helpers
        end
    end
end
