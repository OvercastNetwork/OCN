class User
    # Forum related stuff
    module Forums
        extend ActiveSupport::Concern

        included do
            field :forem_auto_subscribe, type: Boolean, default: false
            field :quote_notification, type: Boolean, default: true

            attr_accessible :forem_auto_subscribe, :quote_notification, as: :user
        end # included do
    end # Forums
end
