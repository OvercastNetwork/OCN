class User
    module Nickname
        extend ActiveSupport::Concern

        class Error < Exception
            def problem
                self.class.base_name.upcase
            end
        end

        class Taken < Error; end
        class Invalid < Error; end

        REVEAL_ALL_PERMISSION = 'nick.see-through-all'

        included do
            field :nickname
            field :nickname_lower
            field :nickname_updated_at

            unset_if_nil :nickname_lower # Required for the sparse index to work properly
            attr_accessible :nickname, :nickname_updated_at
            api_property :nickname, :nickname_updated_at

            index({nickname_lower: 1}, {sparse: true, unique: true})

            validates_format_of :nickname, with: Identity::USERNAME_REGEX, allow_nil: true
            validates_format_of :nickname_lower, with: Identity::USERNAME_NORMALIZED_REGEX, allow_nil: true

            before_validation do
                if nickname_changed?
                    if nickname?
                        self.nickname = nickname.strip
                        self.nickname_lower = User.normalize_username(nickname)
                    else
                        self.nickname_lower = nil
                    end
                end
            end
        end

        module ClassMethods
            def by_nickname(name)
                where(username_lower: normalize_username(name)).first if name
            end

            def by_username_or_nickname(name)
                if user = by_username(name)
                    matched_nick = false
                elsif user = by_nickname(name)
                    matched_nick = true
                end

                [user, matched_nick]
            end

            def check_nickname(nickname)
                if by_nickname(nickname)
                    raise Taken, "Nickname '#{nickname}' is in use by another player"
                elsif by_username(nickname)
                    raise Taken, "Nickname '#{nickname}' is the real name of a player (local)"
                elsif Mojang.username_taken?(nickname)
                    raise Taken, "Nickname '#{nickname}' is the real name of a player (remote)"
                end
            end
        end

        def can_see_through_disguises?
            has_mc_permission?(REVEAL_ALL_PERMISSION)
        end

        def reveal_disguises_to?(viewer = User.current)
            viewer.can_see_through_disguises? || viewer.friend?(self)
        end

        def disguised_to_anybody?
            nickname
        end

        def disguised_to?(viewer = User.current)
            (nickname && !reveal_disguises_to?(viewer)).to_bool
        end

        def set_nickname!(nickname)
            User.check_nickname(nickname) if nickname
            update_attributes!(nickname: nickname, nickname_updated_at: Time.now)
        rescue Mongoid::Errors::Validations => ex
            if errors.to_h.all?{|attr, _| attr.to_sym == :nickname }
                raise Invalid, "Nickname '#{nickname}' #{errors[:nickname].first}"
            else
                raise
            end
        rescue Mongo::Error::OperationFailure => ex
            if ex.message =~ /duplicate key/
                raise Taken, "Nickname '#{nickname}' is in use by another player"
            else
                raise
            end
        end
    end
end
