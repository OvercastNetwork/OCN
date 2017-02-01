module Action
    class Comment < Base
        token :comment

        def rich_description
            [{:user => user, :message => " commented"}]
        end
    end
end
