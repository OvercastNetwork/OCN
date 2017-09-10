class Friendship
    include Mongoid::Document
    store_in :database => "oc_friendships"

    include Subscribable
    include ApiModel

    class Alert < Subscription::Alert
        include UserHelper

        alias_method :friendship, :subscribable

        def link
            if user == friendship.friender
                user_path(friendship.friended)
            else
                user_path(friendship.friender)
            end
        end

        def rich_message
            if user == friendship.friender && friendship.decision?
                [{user: friendship.friended, message: " accepted your friend request"}]
            elsif user == friendship.friended
                [{user: friendship.friender, message: " has requested to be your friend"}]
            else
                []
            end
        end
    end

    # [friender, friended]
    has_and_belongs_to_many :users, inverse_of: nil

    index(INDEX_users_decision = {user_ids: 1, decision: 1})
    index(INDEX_friender_friended_decision = {'user_ids.0' => 1, 'user_ids.1' => 1, decision: 1})

    index({'user_ids.0' => 1, decision: 1})
    index({'user_ids.1' => 1, decision: 1})

    def friender_id
        user_ids[0]
    end

    def friended_id
        user_ids[1]
    end

    def friender
        # Mongoid does NOT guarantee #users has the same order as #user_ids
        if users[0].id == friender_id
            users[0]
        else
            users[1]
        end
    end

    def friended
        # Mongoid does NOT guarantee #users has the same order as #user_ids
        if users[1].id == friended_id
            users[1]
        else
            users[0]
        end
    end

    field :decision, type: Boolean
    field :sent_date, type: DateTime
    field :decision_date, type: DateTime

    attr_accessible :users, :user_ids, :decision

    api_property :sent_date, :decision_date

    api_synthetic :friender do
        friender.player_id
    end

    api_synthetic :friended do
        friended.player_id
    end

    api_synthetic :undecided do
        decision == nil
    end

    api_synthetic :accepted do
        decision == true
    end

    api_synthetic :rejected do
        decision == false
    end

    scope :involving, -> (user) { where(user_ids: user.id) }
    scope :friender, -> (user) { where('user_ids.0' => user.id) }
    scope :friended, -> (user) { where('user_ids.1' => user.id) }
    scope :from_to, -> (a, b) { friender(a).friended(b) }
    scope :betwixt, -> (a, b) { (from_to(a, b) | from_to(b, a)).hint(INDEX_friender_friended_decision) }

    scope :by_decision_date, desc(:decision_date)
    scope :undecided, where(decision: nil)
    scope :accepted, where(decision: true)
    scope :rejected, where(decision: false)

    class << self
        def max_default_friends
            16
        end

        def user_ids(except: nil)
            all.flat_map(&:user_ids).uniq - [*except].map(&:id)
        end

        def users(except: nil)
            User.in(id: user_ids(except: except))
        end

        def friends?(a, b)
            a == b || betwixt(a, b).accepted.exists?
        end

        def mutual_friends(a, b)
            User.in(id: (a.friendships.flat_map(&:user_ids) & b.friendships.flat_map(&:user_ids)).uniq - [a.id, b.id])
        end
    end

    def initialize(users: nil, friender: nil, friended: nil, **opts)
        opts[:user_ids] ||= [friender.id, friended.id] if friender && friended
        super(**opts)
    end

    before_create do
        self.friender.can_request_friends?
        self.sent_date ||= Time.now
    end

    after_create do
        self.subscribe_user(friended)
        self.alert_subscribers
        self.subscribe_user(friender)
    end

    before_save do
        self.decision_date = Time.now if decision_changed? && decided?
    end

    around_save :alert_on_decision
    def alert_on_decision
        decided = decision_changed? && decided?
        saved = yield
        alert_subscribers(except: friended) if decided && saved && decision?
    end

    after_save :clear_cache
    after_destroy :clear_cache

    def clear_cache
        friender.clear_friendship_cache
        friended.clear_friendship_cache
    end

    def decide!(value)
        if undecided?
            self.decision = value
            self.save!
        end
    end

    def undecided?
        decision.nil?
    end

    def decided?
        !undecided?
    end

    def accepted?
        decision == true
    end

    def rejected?
        decision == false
    end

    def involves?(user)
        user_ids.include?(user.id)
    end

    def can_update?(user)
        user.id == friended_id && !accepted?
    end

    def can_destroy?(user)
        if user.id == friender_id
            # Friender cannot cancel a rejected request
            !rejected?
        elsif user.id == friended_id
            # Friended can only unfriend if they have previously accepted
            accepted?
        end
    end
end
