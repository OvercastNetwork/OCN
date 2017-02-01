class User
    module TntLicense
        extend ActiveSupport::Concern

        included do
            field :requested_tnt_license_at, type: Time
            field :granted_tnt_license_at, type: Time
            field :tnt_license_kills, type: Array, default: [].freeze

            props = :requested_tnt_license_at, :granted_tnt_license_at, :tnt_license_kills
            api_property *props
            attr_accessible *props

            after_save do
                if trophy = Trophy.find('sapper')
                    if has_tnt_license?
                        trophy.give_to(self)
                    else
                        trophy.take_from(self)
                    end
                end
            end

            alias_method :requested_tnt_license?, :requested_tnt_license_at
            alias_method :has_tnt_license?, :granted_tnt_license_at
        end
    end
end
