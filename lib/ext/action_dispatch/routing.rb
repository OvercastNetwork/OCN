module ActionDispatch::Routing
    module ModelRouteHelpers
        # Helper to create routes for a ModelController subclass
        def models(*names, &block)
            resources(*names) do
                collection do
                    # Find multiple documents (would prefer to do this with the root path,
                    # but POSTing to that is already mapped to #create)
                    post :find_multi, action: :index

                    # Update multiple documents.. see ModelController for parameter details
                    post :update_multi
                end

                instance_exec(&block) if block
            end
        end
    end

    class Mapper
        include ModelRouteHelpers
    end
end
