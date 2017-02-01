module Action
    class Close < Base
        token :close

        def rich_description
            [{:user => user, :message => " closed the #{actionable.description}"}]
        end
    end
end
