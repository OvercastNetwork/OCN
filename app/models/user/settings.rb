class User
    module Settings
        extend ActiveSupport::Concern

        included do
            field :settings,
                  as: :mc_settings_by_profile,
                  type: Hash,
                  default: -> { {} } # mc settings by profile name

            api_synthetic :mc_settings_by_profile
            attr_accessible :mc_settings_by_profile
        end

        def get_settings(profile)
            mc_settings_by_profile[profile] || {}
        end

        def change_setting!(profile, setting, value)
            if value.nil?
                if h = settings[profile]
                    h.delete(setting)
                    settings.delete(profile) if h.empty?
                end
            else
                settings[profile] ||= {}
                settings[profile][setting] = value
            end
            save!
        end
    end
end
