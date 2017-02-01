module Action
    class Lock < Base
        token :lock

        def rich_description
            [{:user => user, :message => " locked the #{actionable.description}"}]
        end
    end
end
