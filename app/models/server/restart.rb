class Server
    module Restart
        extend ActiveSupport::Concern
        include Lifecycle

        class Priority
            LOW = -10           # Restart only if it won't inconvenience any players
            NORMAL = 0          # Restart at the next reasonable opportunity (e.g. after the current match)
            HIGH = 10           # Restart immediately
        end

        included do
            # A value in this field indicates that the server is being allowed to restart,
            # and is trying to do so. When a server sees that this field is set, it should shut
            # itself down at the next safe opportunity i.e. when it's empty. Everything else
            # should try to help give the server a chance to shutdown by e.g. not sending
            # more players to it, and should also assume that the server could go offline
            # at any moment.
            #
            # The model code ensures that this and dns_enabled are never both set at the
            # same time. In other words, a restart is queued if and only if DNS is disabled.
            #
            # This field is normally cleared by calling #startup, which the server does when
            # it starts up again. When clearing the field in any other way, care must be taken
            # to ensure that the server has not already committed to a shutdown. For this
            # reason, only the server itself should be allowed to cancel queued restarts.
            field :restart_queued_at, type: Time
            field :restart_reason, type: String
            field :restart_priority, type: Integer, default: Priority::NORMAL

            props = [:restart_queued_at, :restart_reason, :restart_priority]
            attr_accessible *props
            api_property *props

            # Lobbies need to restart one at a time, so they need an additional layer
            # of state to coordinate.
            field :rolling_restart_queued, :type => Boolean, :default => false

            before_event :up_or_down do
                self.restart_queued_at = nil
                self.restart_reason = nil
                self.rolling_restart_queued = false
                true
            end

            after_event :startup do
                lobby? and self.class.datacenter(datacenter).lobbies.continue_rolling_restart
            end
        end

        module ClassMethods
            # Select servers that are currently trying to restart
            def restart_queued(yes)
                if yes
                    ne(restart_queued_at: nil)
                else
                    where(restart_queued_at: nil)
                end
            end

            # Select servers that are currently part of a rolling restart, and have not restarted yet
            def rolling_restart_queued(yes)
                if yes
                    where(rolling_restart_queued: true)
                else
                    ne(rolling_restart_queued: true)
                end
            end

            # Queue a restart on all selected servers
            def queue_restart(reason: nil, priority: nil)
                online.restart_queued(false).each{|s| s.queue_restart(reason: reason, priority: priority) }
            end

            # Cancel any queued restart on all selected servers
            def cancel_restart
                online.restart_queued(true).each{|s| s.cancel_restart }
            end

            # Begin a rolling restart of all selected servers
            def queue_rolling_restart(reason: nil)
                online.rolling_restart_queued(false).update_all(rolling_restart_queued: true, restart_reason: reason)
                continue_rolling_restart
            end

            # Cancel any rolling restart for all selected servers
            def cancel_rolling_restart
                online.rolling_restart_queued(true).update_all(rolling_restart_queued: false)
            end

            # If any of the selected servers are waiting for a rolling restart,
            # and none of them are queued to restart or offline, queue one of them
            # to restart.
            #
            # This should be called once on each group of servers that must restart
            # sequentially with respect to each other.
            def continue_rolling_restart
                rolling = rolling_restart_queued(true)
                rolling.map(&:datacenter).uniq.compact.each do |dc|
                    rolling_dc = rolling.datacenter(dc)
                    unless rolling_dc.online.restart_queued(true).exists? || rolling_dc.offline.exists?
                        if server = rolling_dc.online.restart_queued(false).asc(:num_online).first
                            server.queue_restart
                        end
                    end
                end
            end
        end # ClassMethods

        # If the restart_queued_at field is nil, set it to now, indicating that this
        # server will restart as soon as safely possible.
        def queue_restart(reason: nil, priority: nil)
            now = Time.now.utc
            q = where_self.online

            # If already queued, use the earlier timestamp, the higher priority,
            # and only update the reason if a new value is present. This prevents
            # low-priority request from replacing a high-priority one.
            r2 = q.restart_queued(true).find_one_and_update({$min => {restart_queued_at: now},
                                                             $max => {restart_priority: priority}}
                                                                .merge_if(reason, $set => {restart_reason: reason}))

            # If not already queued, ensure everything is set
            r1 = q.restart_queued(false).find_one_and_update($set => {restart_queued_at: now,
                                                                      restart_reason: reason || "no reason",
                                                                      restart_priority: priority || Priority::NORMAL})
            if r1 || r2
                reload
                api_sync!
            end
        end

        # Clear the restart_queued_at field. See the documentation for that field
        # for reasons to be careful when calling this method.
        def cancel_restart
            if restart_queued_at?
                update_attributes!(restart_queued_at: nil)
            end
        end

        def restart_text
            if restart_queued_at?
                "Queued"
            elsif rolling_restart_queued?
                "Rolling"
            else
                ""
            end
        end

        def restart_color
            if restart_queued_at?
                "status-warning"
            elsif rolling_restart_queued?
                "status-error"
            else
                ""
            end
        end
    end
end
