class User
    # Adds the class method User.current which returns a User who is
    # implicitly the viewer/actor in any operations. This user is stored
    # in a thread-local variable.
    #
    # The base controller sets this to the currently logged in user for
    # the duration of each request. Whenever the current user is not set,
    # the #current method returns the anonymous user.
    module Current
        extend ActiveSupport::Concern

        included do
            before_save do
                !anonymous? && !console?
            end
        end

        def anonymous?
            self == self.class.anonymous_user
        end

        def console?
            self == @console_user
        end

        class << self
            # User instance to represent unauthenticated users
            def anonymous_user
                @anonymous_user ||= User.new
            end

            def console_user
                unless @console_user
                    @console_user = User.new
                    @console_user.admin = true
                    @console_user.api_key_digest = CONSOLE_USER_KEY_DIGEST
                end
                @console_user
            end
        end

        CURRENT_USER = ThreadLocal.new{ anonymous_user }

        module ClassMethods
            delegate :anonymous_user, to: User::Current
            delegate :console_user, to: User::Current

            def current
                CURRENT_USER.get
            end

            def set_current(user)
                CURRENT_USER.set(user || Current.anonymous_user)
            end

            def with_current(user, &block)
                CURRENT_USER.with(user || Current.anonymous_user, &block)
            end
        end
    end
end
