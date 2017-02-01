class Alert
    include Mongoid::Document
    include Mongoid::Timestamps
    include BackgroundIndexes
    include ActionView::Helpers::DateHelper
    store_in :database => "oc_forem_alerts", :collection => "forem_alerts"

    belongs_to :user
    field :read, :type => Boolean, :default => false
    field :read_at, :type => Time

    scope :user, -> (u) { where!(user: u).hint(INDEX_user) }
    scope :unread, ne(read: true)
    scope :unread_by, -> (u) { user(u).unread.hint(INDEX_user_read) }

    attr_accessible :user, :user_id

    validates_presence_of :user

    index({_type: 1})
    index(INDEX_user = {user_id: 1, updated_at: -1})
    index(INDEX_user_read = {user_id: 1, read: 1, updated_at: -1})

    class << self
        def mark_read!
            unread.mark_read_now!
        end

        def mark_read_now!
            update_all(read: true, read_at: Time.now)
        end
    end

    def mark_read!
        self.class.where(atomic_selector).unread.mark_read_now!
    end

    def link
        Rails.application.routes.url_helpers.root_path
    end

    def rich_message
        [{message: "<#{self.class} _type=#{self[:_type]}>"}]
    end
end
