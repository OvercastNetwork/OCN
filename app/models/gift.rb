class Gift
    include Mongoid::Document
    include Mongoid::Timestamps
    store_in :database => "oc_gifts"

    include RequestCacheable

    ACTIVE_FOR = 24.hours
    SEASON_LENGTH = 90.days

    class Alert < ::Alert
        include UserHelper

        def link
            user_path(user)
        end

        def rich_message
            [{message: "Your gift request was granted by a secret santa!"}]
        end
    end

    belongs_to :user, validates: {reference: true, real_user: true}
    belongs_to :package, validates: {reference: true}
    belongs_to :given_by, class_name: 'User', validates: {reference: true, real_user: true, allow_nil: true}

    field :comment, type: String, validates: {presence: true, length: {maximum: 140}}
    field :raindrops, type: Integer, default: 0, validates: {numericality: true}

    attr_accessible :package, :comment, :raindrops

    validates_each :given_by do |gift, attr, value|
        gift.user == value and gift.errors.add(attr, "cannot also be the receiver of the gift")
    end

    scope :purchased, -> (yes) { yes ? ne(given_by: nil) : where(given_by: nil) }
    index(INDEX_given_by = {metadata(:given_by).foreign_key => 1})
    scope :given_by, -> (user) { where(given_by: user).hint(INDEX_given_by) }

    index(INDEX_user = {metadata(:user).foreign_key => 1})
    scope :user, -> (user) { where(user: user).hint(INDEX_user) }

    scope :not_expired, -> (now = Time.now) { gt(created_at: now - ACTIVE_FOR) }
    scope :this_season, -> (now = Time.now) { gt(created_at: now - SEASON_LENGTH) }
    scope :giveable, -> { purchased(false).not_expired }

    index(INDEX_wishful_elves = {given_by: 1, created_at: 1, raindrops: 1})
    scope :wishful_elves, -> {
        giveable.desc(:raindrops).asc(:id).hint(INDEX_wishful_elves)
    }

    index(INDEX_happy_children = {given_by: 1, updated_at: -1})
    scope :happy_children, -> (now = Time.now) {
        purchased(true).this_season(now).desc(:updated_at).hint(INDEX_happy_children)
    }

    class << self
        alias_method :for_user, :user

        def has_open_request?(user = User.current)
            !user.anonymous? && user(user).giveable.exists?
        end

        def offer!(giver:, receiver:, package:)
            if giver != receiver and gift = user(receiver).giveable.desc(:created_at).find_one_and_update($set => {
                metadata(:given_by).foreign_key => giver.id,
                metadata(:package).foreign_key => package.id
            })

                Alert.user(receiver).create!

                if giver
                    gifts_given = given_by(giver).this_season.count
                    [1, 5, 10].each do |count|
                        if gifts_given >= count
                            # secret-santa3-* is for 2015
                            # TODO: make this work for any year
                            Trophy["secret-santa3-#{count}"].give_to(giver)
                        end
                    end
                end
            end
            gift
        end
    end

    def expires_at
        self.created_at + ACTIVE_FOR
    end

    def expired?
        expires_at.past?
    end

    def purchased?
        !given_by.nil?
    end

    attr_cached :purchase do
        package.purchase(recipient: user)
    end

    def giveable?
        persisted? && !purchased? && !expired? && purchase.valid_now?
    end
end
