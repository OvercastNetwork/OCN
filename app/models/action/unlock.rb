module Action
    class Unlock < Base
        token :unlock

        def rich_description
            [{:user => user, :message => " unlocked the #{actionable.description}"}]
        end
    end
end
