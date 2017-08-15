class Group
    include Mongoid::Document
    store_in :database => "oc_forem_groups", :collection => "forem_groups"

    include BackgroundIndexes
    include Permissions::DirectHolder
    include Killable
    include Buildable
    include EagerLoadable
    include RequestCacheable

    DEFAULT_GROUP_NAME = '_default'
    PARTICIPANT_GROUP_NAME = '_Players'
    OBSERVER_GROUP_NAME = '_Observers'
    MAPMAKER_GROUP_NAME = '_Mapmakers'
    REQUIRED_GROUP_NAMES = [DEFAULT_GROUP_NAME, PARTICIPANT_GROUP_NAME, OBSERVER_GROUP_NAME, MAPMAKER_GROUP_NAME]

    field :name, type: String, validates: {presence: true}
    field :priority, type: Integer, default: 0, validates: {presence: true}
    field :staff, type: Boolean, default: false
    field :description, type: String

    field :html_color, type: String

    field :badge_type, type: String # nil, 'youtube'
    field :badge_color, type: String
    field :badge_text_color, type: String, default: "white".freeze
    field :badge_link, type: String

    # { 'realm1' => ['perm1', 'perm2', ...],
    #   'realm2' => ['perm3', 'perm4', ...] }
    field :minecraft_permissions, type: Hash, default: {}.freeze

    Flair = Struct.new(:symbol, :color)

    # { realm => {symbol: ... , color: ...} }
    field :minecraft_flair, type: Hash, default: {}.freeze

    validates 'minecraft_flair.*.color', chat_color: true

    attr_cached :minecraft_flair do
        read_attribute(:minecraft_flair).mash do |realm, flair|
            [realm, Flair.new(flair['symbol'], flair['color'])]
        end
    end

    index({name: 1})

    blank_to_nil :html_color, :badge_type, :badge_color, :badge_text_color, :badge_link

    properties = [:name, :priority,
                  :html_color,
                  :badge_type, :badge_color, :badge_text_color, :badge_link,
                  :minecraft_permissions, :web_permissions, :staff,
                  :minecraft_flair]

    attr_accessible *properties
    attr_buildable *properties

    scope :for_gizmo, -> (name) { where(name: "Gizmo: #{name.gsub(/\s+/,'').downcase}") }
    scope :staff, where(staff: true)
    scope :by_priority, asc(:priority)
    scope :by_reverse_priority, desc(:priority)

    # EagerLoadable
    index_in_memory :name

    validates_collection_with do |loader|
        REQUIRED_GROUP_NAMES.each do |name|
            unless loader.living_docs.any?{|group| group.name == name}
                loader.add_error("Missing a required special group named '#{name}'")
            end
        end
    end

    class << self
        def magic_name_group(name)
            by_name(name) or raise "Missing magic group '#{name}'"
        end

        def default_group
            magic_name_group(DEFAULT_GROUP_NAME)
        end

        def participant_group
            magic_name_group(PARTICIPANT_GROUP_NAME)
        end

        def observer_group
            magic_name_group(OBSERVER_GROUP_NAME)
        end

        def mapmaker_group
            magic_name_group(MAPMAKER_GROUP_NAME)
        end

        def by_name(name)
            imap_where(name: name)
        end

        def with_member(user)
            imap.values_at(*user.memberships.select(&:active?).map{|m| {'_id' => m.group_id} }).compact
        end

        def encode_mc_permission(name, value)
            if value
                name
            else
                "-#{name}"
            end
        end

        def decode_mc_permission(perm)
            perm =~ /^([+-])?(.*)/
            [$2, $1 != '-']
        end

        # Convert a sequence of permissions using +/- prefix notation
        # to a {name => boolean} map. Elements later in the sequence
        # will override earlier ones.
        def decode_mc_permissions(perms)
            perms.mash do |perm|
                decode_mc_permission(perm)
            end
        end

        def merge_mc_permissions(base, perms)
            base.merge(decode_mc_permissions(perms))
        end
    end

    def html_color_css
        html_color || 'none'
    end

    def badge_color_css
        badge_color || 'none'
    end

    def has_badge?
        badge_type || (badge_color && badge_color != 'none')
    end

    def to_s
        name
    end

    def magic?
        name =~ /^_/
    end

    def members(active=true)
        User.in_group(self, at: active ? Time.now : nil)
    end

    def members_by_seniority
        User.in_group(self).sort_by do |user|
            user.memberships.find_by(group: self).start
        end
    end

    def merge_mc_permissions(base, realms)
        # Note: realms applied in the order they are passed to this method
        realms.each do |realm|
            base = self.class.merge_mc_permissions(base, self.minecraft_permissions[realm].to_a)
        end
        base
    end

    # Return a map of the perms added and removed by this group in the given realms.
    # Realms later in the list will override earlier ones.
    def mc_permission_map(realms)
        m = {}
        realms.each do |realm|
            if perms = minecraft_permissions[realm]
                perms.each do |perm|
                    k, v = self.class.decode_mc_permission(perm)
                    m[k] = v
                end
            end
        end
        m
    end

    def self.can_manage?(group, user = nil)
        user && (user.admin? || user.has_permission?('group', group.id.to_s, 'manage', true))
    end

    def can_manage?(user = nil)
        Group.can_manage?(self, user)
    end

    def can_delete?(user = nil)
        self.can_manage?(user) || (user && user.has_permission?('group', self.id.to_s, 'delete', true))
    end

    def self.can_edit?(field, group, user = nil)
        return user && (Group.can_manage?(group, user) || user.has_permission?('group', group.id.to_s, 'edit', field.to_s, true))
    end

    def can_edit?(field, user = nil)
        Group.can_edit?(field, self, user)
    end

    def self.can_edit_any?(group, user = nil)
        (Group.accessible_attributes.collect{|f| f.to_s} + %w(members)).any?{|field| Group.can_edit?(field, group, user)}
    end

    def can_edit_any?(user = nil)
        Group.can_edit_any?(self, user)
    end

    def expires(user)
        user.memberships.where(group_id: self.id).one.stop
    end

    def premium?
        staff || !Package.for_group(self).nil?
    end
end
