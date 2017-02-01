module Action
    class Open < Base
        token :open

        def rich_description
            [{:user => user, :message => " re-opened the #{actionable.description}"}]
        end
    end
end
