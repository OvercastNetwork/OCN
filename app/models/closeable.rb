module Closeable
    extend ActiveSupport::Concern
    include Actionable

    included do
        field :open, type: Boolean, default: true

        scope :opened, where(open: true)
        scope :closed, ne(open: true)

        action Action::Open do
            self.open = true
            self.locked = false if is_a? Lockable
        end

        action Action::Close do
            self.open = false
        end
    end

    def closed?
        !open?
    end
end
