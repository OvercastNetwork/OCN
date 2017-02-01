class User
    module Profile
        extend ActiveSupport::Concern

        SHORT_FIELD_NAMES = [:public_email, :gender, :location, :occupation, :interests,
                             :skype, :twitter, :facebook, :steam, :reddit, :github, :twitch,
                             :discord].freeze

        FIELD_NAMES = [*SHORT_FIELD_NAMES, :about].freeze

        included do
            FIELD_NAMES.each do |name|
                field name, type: String
                attr_accessible name, as: :user
                blank_to_nil name
            end

            SHORT_FIELD_NAMES.each do |name|
                validates_length_of name, maximum: 140, allow_nil: true
            end

            field :time_zone_name, type: String
            attr_accessible :time_zone_name, as: :user

            validates_each(:time_zone_name, allow_nil: true) do |user, attr, tz|
                begin
                    TZInfo::Timezone.get(tz)
                rescue TZInfo::InvalidTimezoneIdentifier
                    user.errors.add attr, "is not a known time zone"
                end
            end

            # List of profile fields that the user is not allowed to edit
            field :restricted_fields, type: Array, default: [].freeze
            validates_elements_of :restricted_fields, inclusion: {in: FIELD_NAMES.map(&:to_s)}
            attr_accessible :restricted_fields
        end # included do

        def banned_updates
            if is_banned?
                FIELD_NAMES
            else
                restricted_fields.map(&:to_sym)
            end
        end

        def display_profile_to?(viewer = User.current)
            !suspended? || viewer.has_permission?('misc', 'player', 'view_suspended', true)
        end

        def can_edit_verified_profile?(user = User.current)
            user.has_permission?(:user, :profile, :verified, :edit, self == user ? :own : :all)
        end
    end # Profile
end
