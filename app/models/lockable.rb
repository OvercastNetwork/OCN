module Lockable
    extend ActiveSupport::Concern
    include Actionable

    included do
        field :locked, type: Boolean, default: false

        scope :locked, where(locked: true)
        scope :unlocked, ne(locked: true)

        action Action::Lock do
            self.locked = true
            self.open = false if is_a? Closeable
        end

        action Action::Unlock do
            self.locked = false
        end
    end

    def unlocked?
        !locked?
    end
end
