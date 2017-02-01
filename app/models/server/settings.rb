class Server
    module Settings
        extend ActiveSupport::Concern

        included do
            field :settings_profile, type: String

            attr_cloneable :settings_profile

            api_property :settings_profile
        end # included do
    end # Settings
end
