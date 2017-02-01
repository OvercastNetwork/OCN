module Action
    class Unappeal < OnPunishment
        token :unappeal

        def rich_description
            [{:user => user, :message => " unappealed "},
             {:user => actionable.punished, :message => "'s "},
             *punishment_rich_description]
        end
    end
end
