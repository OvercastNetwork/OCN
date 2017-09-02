class Map
    include Mongoid::Document
    include BackgroundIndexes
    store_in :database => "oc_maps"

    include ApiModel

    class VersionValidator < ActiveModel::EachValidator
        def validate_each(obj, attr, value)
            unless value.is_a?(Array) && value.size >= 2 && value.all?{|n| n.is_a? Integer }
                obj.errors.add(attr, "must be a sequence of two or more integers")
            end
        end
    end

    has_many :fucking_matches, class_name: 'Match'
    has_many :engagements

    class Genre < Enum
        create :OBJECTIVES, :DEATHMATCH, :OTHER
        # blitz? rage? survival?
    end

    field :genre, type: Genre, default: Genre::OTHER
    index({genre: 1})

    class Edition < Enum
        create :STANDARD, :RANKED, :TOURNAMENT # priority order
        DEFAULT = STANDARD
    end
    field :edition, type: Edition, default: Edition::DEFAULT
    field_scope :edition

    class Phase < Enum
        create :PRODUCTION, :DEVELOPMENT # priority order
        DEFAULT = PRODUCTION
    end
    field :phase, type: Phase, default: Phase::DEFAULT
    field_scope :phase
    scope :production, -> { phase(Phase::PRODUCTION) }

    scope :default_variant, edition(Edition::DEFAULT).phase(Phase::DEFAULT)

    GAMEMODES = {
        tdm:        {name: "Team Deathmatch"},
        ctw:        {name: "Capture the Wool"},
        ctf:        {name: "Capture the Flag"},
        dtc:        {name: "Destroy the Core"},
        dtm:        {name: "Destroy the Monument"},
        ad:         {name: "Attack/Defend"},
        koth:       {name: "King of the Hill"},
        blitz:      {name: "Blitz"},
        rage:       {name: "Rage"},
        arcade:     {name: "Arcade"},
        ffa:        {name: "Free-for-all"},
        mixed:      {name: "Mixed"},
    }

    field :_id,             type: String, overwrite: true # Derived from other fields, see #normalize
    field :name,            type: String # Arbitrary string
    field :slug,            type: String # Readable string for URLs
    field_scope :slug
    field :version,         type: Array  # Two or more ints
    field :path,            type: String # Absolute local path the map was loaded from
    field :url,             type: String # Public URL of map folder
    field :images,          type: Array, default: [].freeze  # Screenshot file names

    field :gamemode,        type: Array, default: [].freeze  # Set of keys from GAMEMODES
    scope :gamemode, -> (gamemode) { where(gamemode: gamemode) }

    field :author_names,    type: Array, default: [].freeze # Authors that are not players
    field :author_uuids,    type: Array, default: [].freeze # Authors that are players
    field :contributor_uuids, type: Array, default: [].freeze # Secondary contributors

    # User.id of authors in our DB
    has_and_belongs_to_many :authors, class_name: 'User', inverse_of: nil

    scope :author, -> (user) { where(author_ids: user.id) }

    field :objective,       type: String
    field :min_players,     type: Integer, default: 0
    field :max_players,     type: Integer

    embeds_many :teams, class_name: 'Map::Team'
    accepts_nested_attributes_for :teams

    class Team
        include Mongoid::Document
        include ApiModel
        embedded_in :map

        field :_id,         type: String, overwrite: true # Matches PGM's feature ID
        field :name,        type: String
        field :min_players, type: Integer, default: 0
        field :max_players, type: Integer
        field :color,       type: String # ChatColor.name

        def chat_color
            ChatColor[color] if color
        end

        def html_color
            cc = chat_color and cc.to_html
        end

        properties = [:name, :min_players, :max_players, :color]
        attr_accessible :_id, *properties
        api_property *properties

        validates :name, presence: true
        validates :max_players, numericality: true
        validates :color, inclusion: { in: ChatColor::COLORS.map{|c| c.name.to_s } }
    end

    def team_by_name(name)
        teams.to_a.find{|t| t.name == name }
    end

    class Ratings
        include Mongoid::Document
        embedded_in :map

        # Minimum ratings for a confident aggregate score
        THRESHOLD = 300

        field :count, type: Integer, default: 0     # Number of votes
        field :total, type: Integer, default: 0     # Sum of all votes

        # Number of votes by score (length is always 5)
        field :dist, type: Array, default: -> { [0] * 5 }

        def to_s
            "Map::Ratings{count=#{count} total=#{total} dist=#{dist}}"
        end

        def mean
            total.to_f / count.to_f
        end

        def confident?
            count >= THRESHOLD
        end

        def confident_mean
            if confident?
                mean
            else
                0
            end
        end
    end

    embeds_one :current_ratings, class_name: 'Map::Ratings', inverse_of: nil
    embeds_one :lifetime_ratings, class_name: 'Map::Ratings', inverse_of: nil
    field :average_rating, type: Float, default: 0

    # True iff the map is loaded in the repo. If a map is removed,
    # or the import of an existing map fails, this will be set false.
    field :loaded, type: Boolean, default: true
    scope :loaded, where(loaded: true)

    # True: ratings visible to the general publiv
    # False: ratings only visible to staff and authors
    field :public_ratings, type: Boolean


    validates_presence_of :genre
    validates_presence_of :edition
    validates_presence_of :phase

    validates :gamemode, presence: true
    validates_each :gamemode do |map, attr, value|
        value.each do |gm|
            unless GAMEMODES.key?(gm.to_sym)
                map.errors.add(attr, "includes an invalid gamemode '#{gm}'")
            end
        end
    end

    validates_presence_of :name
    validates_presence_of :slug
    validates :version, 'Map::Version' => true

    validates_presence_of :current_ratings
    validates_presence_of :lifetime_ratings
    validates_presence_of :average_rating

    properties = [
        :name, :slug, :version,
        :genre, :edition, :phase, :gamemode,
        :author_uuids, :contributor_uuids,
        :path, :url, :images,
        :objective, :teams,
        :min_players, :max_players
    ]

    attr_accessible :_id, *properties
    api_property *properties

    index({name: 1})
    index({slug: 1})
    index({gamemode: 1})
    index({author_ids: 1})
    index({average_rating: -1})
    index({public_ratings: -1, average_rating: -1})

    before_validation :normalize
    before_save :normalize

    def normalize
        self.slug ||= self.name.slugify if self.name
        self.id = self.class.make_id(slug, edition, phase)
        self.version = self.class.parse_version(self.version)
        self.max_players = teams.sum(&:max_players)

        self.current_ratings ||= Ratings.new
        self.lifetime_ratings ||= Ratings.new

        self.average_rating = if current_ratings.confident?
            current_ratings.mean
        else
            lifetime_ratings.confident_mean
        end

        teams.each do |team|
            team.color = ChatColor[team.color].name if team.color
        end

        true
    end

    before_save do
        self.public_ratings ||= in_any_rotations?
        true
    end

    def formatted_version
        version.join('.')
    end

    def thumbnail_url
        if url && !images.to_a.empty?
            File.join(url, images[0])
        else
            self.class.missing_thumbnail_url
        end
    end

    def xml_url
        File.join(url, "map.xml") if url
    end

    def author?(user)
        self.author_ids.include?(user.id)
    end

    def view_permission(**opts)
        opts[:phase] ||= phase
        self.class.view_permission(**opts)
    end

    def can_view?(**opts)
        user = opts.delete(:user) || User.current
        user.has_permission?(view_permission(ownership: :all, **opts)) || (
            author?(user) && user.has_permission?(view_permission(ownership: :own, **opts))
        )
    end

    def can_view_ratings?(user = User.current)
        visibility = if public_ratings?
            'public'
        else
            'private'
        end

        Map.can_view_ratings?(user, visibility, 'all') || (author?(user) && Map.can_view_ratings?(user, visibility, 'own'))
    end

    def has_rating?(viewer = User.current)
        can_view_ratings?(viewer) && average_rating > 0
    end

    def visible_rating(viewer = User.current)
        if can_view_ratings?(viewer)
            average_rating
        else
            0
        end
    end

    def visible_rating_text(viewer = User.current)
        if has_rating?(viewer)
            sprintf("Player rating: %.2f", visible_rating(viewer))
        else
            "No player rating"
        end
    end

    def in_any_rotations?
        Server.rotation_map_ids.include?(id)
    end

    def variant_id(edition: self.edition, phase: self.phase)
        self.class.make_id(slug, edition, phase)
    end

    def variant(**attrs)
        id = variant_id(**attrs)
        if id == self.id
            self
        else
            self.class.find(id)
        end
    end

    def variants
        self.class.slug(slug)
    end

    def can_download?(user = User.current)
        user.has_permission?(:map, :download, :all) || (author?(user) && user.has_permission?(:map, :download, :own))
    end

    def loaded_from_repository?(repo = nil)
        repo ||= Repository[:maps]
        path && path.start_with?(repo.absolute_path)
    end

    def exists_in_repository?(repo = nil)
        loaded_from_repository?(repo) && File.directory?(path)
    end

    def dist_file_name
        if path
            "#{File.basename(path)}.#{formatted_version}.zip"
        end
    end

    def dist_file(repo = nil)
        repo ||= Repository[:maps]
        if exists_in_repository?(repo)
            Dir.chdir(File.dirname(self.path)) do
                `#{Shellwords.join(['zip', '-r', '-', File.basename(self.path)])}`
            end
        end
    end

    class << self
        def make_id(slug, edition, phase)
            if edition == Edition::DEFAULT && phase == Phase::DEFAULT
                slug
            else
                "#{slug}:#{edition.name.downcase}:#{phase.name.downcase}"
            end
        end

        # Convert rotation file entry to _id
        def id_from_rotation(entry)
            entry.strip.slugify
        end

        # Fetch maps for the given rotation file entries,
        # preserving order and filtering out bad entries
        def from_rotation(*entries)
            ids = entries.map{|entry| id_from_rotation(entry) }
            self.in(id: ids).index_by(&:id).values_at(*ids).compact
        end

        def missing_thumbnail_url
            "https://maps.#{ORG::DOMAIN}/_/map.png"
        end

        def view_permission(phase:, ownership:)
            [:map, :phase, phase.name.downcase, :view, ownership]
        end

        def viewable(user: User.current)
            all.to_a.select{|map| map.can_view?(user: user) }
        end

        def can_view_ratings?(user, visibility, value)
            user.has_permission?('map', 'rating', 'view', visibility, value)
        end

        def can_view_any_ratings?(user)
            can_view_ratings?(user, 'public', 'all')
        end

        def parse_version(version)
            if version.is_a? String
                parse_version(version.scan(/\d+/).map(&:to_i))
            elsif version.is_a? Array
                [version[0] || 1, version[1] || 0, *version[2..-1]]
            end
        end

        def default_variant(maps)
            maps.to_a.select{|map| map.phase == Phase::PRODUCTION }.sort_by(&:edition).first
        end

        def default_variants(maps = all)
            maps = maps.all if maps == Map
            maps.to_a.group_by(&:slug).values.map{|variants| default_variant(variants) }.compact
        end

        def for_slug(slug)
            default_variant(where(slug: slug))
        end

        def for_slugs(slugs)
            default_variants(self.in(slug: slugs.to_a))
        end

        def order_by_rating(viewer = User.current)
            if can_view_ratings?(viewer, 'private', 'all')
                desc(:average_rating)
            elsif can_view_ratings?(viewer, 'public', 'all')
                order_by(public_ratings: -1, average_rating: -1)
            else
                self.all
            end
        end

        def sync_ratings
            maps = all.to_a
            Rails.logger.info "Syncing ratings for #{maps.size} maps" if maps.size > 1 # Filter out single rating events
            Couch::MapRating.update_maps!(*maps)
        end
    end
end
