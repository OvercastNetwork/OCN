class User
    module Premium
        extend ActiveSupport::Concern
        include RequestCacheable
        include Login

        TRIAL_LENGTH = 7.days
        TRIAL_CUTOFF = Time.utc(2017, 8, 21) # Only users who joined after this date are eligible
        TRIAL_GROUP_NAME = '_trial'

        class << self
            def trial_group
                Group.magic_name_group(TRIAL_GROUP_NAME)
            end
        end

        included do
            field :trial_started_at, type: Time
            field :allow_package_gifts, type: Boolean, default: true
            field :shop_lockout_at, type: Time

            has_many :transactions

            attr_accessible :allow_package_gifts, as: :user

            api_synthetic :trial_expires_at

            attr_cached :highest_purchased_package do
                purchased_packages.max_by(&:price) unless anonymous?
            end

            attr_cached :used_premium_time do
                used_premium_time_between(Time::INF_PAST .. Time.now)
            end
        end

        module ClassMethods
            def login(uuid, username, ip, mc_client_version: nil)
                user = super
                user.update_trial!
                user
            end
        end

        def premium?(now = nil)
            now ||= Time.now
            memberships.any?{|m| m.active?(now) && m.group.premium? }
        end

        # Total money spent ON this user in cents
        def money_spent_on
            Transaction.payed.recipient(self).sum(&:total)
        end

        # Total money spent BY this user in cents
        def money_spent_by
            Transaction.payed.buyer(self).sum(&:total)
        end

        def purchased_packages
             Package.imap_all.select{|p| in_group?(p.group, false) }
        end

        # Cumulative time the user has spent as an active
        # member of one or more premium groups.
        def used_premium_time_between(interval)
            return 0.seconds if anonymous?

            # Collect all the times at which the user joined or left a premium group
            # in tuples of [time, action]
            boundaries = []
            memberships.each do |m|
                if m.group.premium?
                    join = [m.start, interval.begin].max
                    leave = [m.stop, interval.end].min
                    if join < leave
                        boundaries << [join, true]
                        boundaries << [leave, false]
                    end
                end
            end

            # Sort all boundaries chronologically
            boundaries.sort_by!{|e| e[0] }

            # Sum the time spans during which the user was in one or more groups
            time = groups = 0
            boundaries.each_cons(2) do |start, stop|
                groups += start[1] ? 1 : -1
                time += stop[0] - start[0] if groups > 0
            end

            time.round
        end

        def used_premium_time_at(now = nil)
            if now
                used_premium_time_between(Time::INF_PAST .. now)
            else
                used_premium_time # cached
            end
        end

        def purchased_premium_time
            if longest = highest_purchased_package
                longest.duration
            else
                0.seconds
            end
        end

        # List of purchases visible to this user in the shop
        def available_purchases(**opts)
            Package.purchases_by_id(recipient: self, **opts)
        end

        def accepts_purchases_from?(buyer = User.current)
            allow_package_gifts? || (buyer && (buyer == self || buyer.admin?))
        end

        def eligible_for_trial?
            mc_first_sign_in_at && mc_first_sign_in_at >= TRIAL_CUTOFF
        end

        def trial_active?(now = nil)
            trial_expires_at(now)
        end

        # Return the time that the user's trial expires, or nil if the trial is inactive
        def trial_expires_at(now = nil)
            now ||= Time.now
            if eligible_for_trial? && !premium?(now)
                start = trial_started_at || now
                finish = start +
                    TRIAL_LENGTH +
                    used_premium_time_between(start..now) # Trial is paused while premium package is active
                finish if finish > now
            end
        end

        # Update the user's membership in the trial group based on
        # a fresh calculation of their remaining trial time. Because
        # the trial can pause and resume, we just call this on every
        # login to keep the group in sync.
        def update_trial!
            if trial = Group.magic_name_group(TRIAL_GROUP_NAME)
                if eligible_for_trial?
                    # If the trial has not started yet, start it once the user
                    # has participated in a match.
                    if trial_started_at.nil? && Participation.user(self).exists?
                        self.trial_started_at = Time.now
                        save!
                    end

                    # Join or leave the trial group if needed
                    if expiry = trial_expires_at
                        join_group(trial, stop: expiry) unless in_group?(trial)
                    else
                        leave_group(trial) if in_group?(trial)
                    end
                else
                    leave_group(trial) if in_group?(trial)
                end
            end
        end

        def check_shop_lockout
            return if shop_lockout_at

            cards = Set[]
            voids = 0
            transactions.desc(:created_at).each do |trans|
                case trans.status
                    when Transaction::Status::PAYED
                        cards.clear
                    when Transaction::Status::DECLINED
                        if trans.processor.is_a?(Transaction::Braintree)
                            cards << trans.processor.credit_card_identifier
                            if cards.size >= 3
                                self.shop_lockout_at = Time.now.utc
                                save!

                                # void transactions (but don't refund)
                                transactions.payed.each do |payed|
                                    if payed.processor_can_void?
                                        payed.refund!
                                        voids += 1
                                    end
                                end

                                Raven.capture_message("Shop lockout: #{username} used #{cards.size} different cards without a successful transaction (#{voids} transactions voided)")
                                break
                            end
                        end
                end
            end
        end
    end
end
