module Action
    class Appeal < OnPunishment
        token :appeal

        def rich_description
            [{:user => user, :message => " appealed "},
             {:user => actionable.punished, :message => "'s "},
             *punishment_rich_description]
        end
    end
end
