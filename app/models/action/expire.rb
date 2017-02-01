module Action
    class Expire < OnPunishment
        token :expire

        def rich_description
            [{:user => user, :message => " expired "},
             {:user => actionable.punished, :message => "'s "},
             *punishment_rich_description]
        end
    end
end
