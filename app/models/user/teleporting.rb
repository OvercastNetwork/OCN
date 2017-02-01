class User
    module Teleporting
        extend ActiveSupport::Concern
        include Servers

        TELEPORT_QUEUE = ThreadLocal.new
        TELEPORT_EXCEPTIONS = ThreadLocal.new([])

        module ClassMethods
            def teleporting(except: [], &block)
                old_exceptions = TELEPORT_EXCEPTIONS.get
                TELEPORT_EXCEPTIONS.set([*old_exceptions, *except])

                TELEPORT_QUEUE.debounce(init: -> { {} },
                                        after: -> (users) { users.each{|user, to| user.teleport_to(to) } },
                                        &block)
            ensure
                TELEPORT_EXCEPTIONS.set(old_exceptions)
            end
        end

        def can_teleport_across_datacenters?
            current_server && has_mc_permission?('server.cross-datacenter', current_server.realms)
        end

        def can_teleport_to_server?(server)
            server && server.online? && (current_datacenter == server.datacenter || can_teleport_across_datacenters?)
        end

        def can_teleport_to_user?(user)
            user != self and
                sighting = user.last_sighting_by(self) and
                sighting.online? and
                user.display_server_to?(self) and
                can_teleport_to_server?(user.current_server)
        end

        def can_teleport_to?(thing)
            case thing
                when User
                    can_teleport_to_user?(thing)
                when Server
                    can_teleport_to_server?(thing)
                else
                    raise TypeError, "Can't teleport to a #{thing.class}"
            end
        end

        def teleport_to(thing)
            unless TELEPORT_EXCEPTIONS.get.include? self
                if TELEPORT_QUEUE.present?
                    TELEPORT_QUEUE.get[self] = thing
                    true
                else
                    case thing
                        when nil
                            teleport_to_lobby_internal
                        when Server
                            teleport_to_server_internal(thing)
                        when User
                            teleport_to_user_internal(thing)
                        else
                            raise TypeError, "Can't teleport to a #{thing.class}"
                    end
                end
            end
        end

        alias_method :teleport_to_user, :teleport_to
        alias_method :teleport_to_server, :teleport_to

        def teleport_to_lobby
            teleport_to(nil)
        end

        private

        def teleport_to_user_internal(user)
            if can_teleport_to_user?(user)
                Publisher::TOPIC.publish(PlayerTeleportRequest.new(self, target_user: user))
                true
            end
        end

        def teleport_to_lobby_internal
            Publisher::TOPIC.publish(PlayerTeleportRequest.new(self, target_server: nil))
            true
        end

        def teleport_to_server_internal(server)
            if server.nil? || can_teleport_to_server?(server)
                Publisher::TOPIC.publish(PlayerTeleportRequest.new(self, target_server: server))
                true
            end
        end
    end
end
