class Trophy
    include Mongoid::Document

    include ApiModel
    include ApiSyncable
    include ApiSearchable

    include Killable
    include Buildable
    include EagerLoadable

    store_in :database => 'oc_trophies'

    field :name, type: String
    field :description, type: String

    field :color, type: String, default: '#3b4c58'.freeze
    field :css_class, type: String
    field :background, type: String, default: '#e8f8f7'.freeze

    props = [:name, :description, :color, :css_class, :background]
    attr_accessible *props
    attr_buildable *props
    validates_presence_of *props
    api_property *props

    # LEGACY
    api_synthetic :identifier do
        self.id.to_s
    end

    class << self
        alias_method :[], :find
    end

    class Alert < ::Alert
        include UserHelper

        belongs_to :trophy
        attr_accessible :trophy

        def link
            user_path(user)
        end

        def rich_message
            [{message: "You earned the '#{trophy.name}' trophy!"}]
        end
    end

    def give_to(user)
        user.trophies << self unless user.trophies.include? self
    end

    def take_from(user)
        user.trophies.delete(self)
    end
end
