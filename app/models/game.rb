class Game
    include Mongoid::Document
    store_in :database => Server::DATABASE_NAME

    include Buildable
    include Killable
    include ApiModel
    include ApiSyncable
    include ApiSearchable

    field :name, type: String # English name
    field :name_normalized, type: String # Lower-case name without whitespace
    field :network, type: Server::Network
    field :priority, type: Integer # Ascending display order
    field :visibility, type: Server::Visibility, default: Server::Visibility::UNLISTED # Equivalent to the field in Server

    has_many :arenas
    has_many :servers

    field_scope :visibility

    validates_presence_of :name, :name_normalized, :priority, :visibility

    before_validation do
        self.name_normalized = Game.normalize_name(self.name)
    end

    scope :visible, -> { where(visibility: Server::Visibility::PUBLIC) }

    props = [:name, :priority, :network, :visibility]
    attr_accessible *props
    attr_buildable *props
    api_property *props

    class << self
        def normalize_name(name)
            name.gsub(/\s/,'').downcase if name
        end

        def by_name(name)
            visible.find_by(name_normalized: normalize_name(name))
        end
    end

    def arena(datacenter)
        arenas.datacenter(datacenter).first_or_create!
    end
end
