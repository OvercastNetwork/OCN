module Action
    class OnPunishment < Base
        belongs_to :punishment, index: true
        attr_accessible :punishment
        validates_presence_of :punishment

        def punishment_rich_description
            if punishment
                path = Rails.application.routes.url_helpers.punishment_path(punishment)
                [{link: path, message: punishment.description}]
            else
                [{message: "punishment"}]
            end
        end
    end
end
