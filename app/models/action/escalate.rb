module Action
    class Escalate < Base
        token :escalate

        def rich_description
            [{:user => user, :message => " escalated the #{actionable.description}"}]
        end
    end
end
