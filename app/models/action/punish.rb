module Action
    class Punish < OnPunishment
        token :punish

        def rich_description
            [{:user => user, :message => " issued a "},
             *punishment_rich_description,
             {message: " to "},
             {:user => actionable.reported}]
        end
    end
end
