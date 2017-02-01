module Action
    class Create < Base
        token :create

        def rich_description
            [{:user => user, :message => " created the #{actionable.description}"}]
        end
    end
end
