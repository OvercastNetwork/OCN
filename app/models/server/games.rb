class Server
    module Games
        extend ActiveSupport::Concern

        included do
            belongs_to :game
            field_scope :game
            api_property :game_id
            attr_cloneable :game

            has_many :tickets

            api_synthetic :waiting_room

            api_synthetic :arena_id do
                arena.id if game?
            end

            before_event :up_or_down do
                tickets.destroy
                true
            end

            around_save do |_, block|
                block.call
            end
        end # included do
        
        module ClassMethods
            def with_participants(servers = all)
                servers.to_a.select{|s| s.tickets.exists? && s.can_join? }
            end

            def without_participants(servers = all)
                servers.to_a.reject{|s| s.tickets.exists? }
            end

            def fullest_needing_participants(servers = all)
                servers.to_a.select{|s| s.participants_needed > 0 }.min_by(&:participants_needed)
            end

            def emptiest_accepting_participants(servers = all)
                servers.to_a.select{|s| s.participants_acceptable > 0 }.max_by(&:participants_acceptable)
            end

            # Find the best server with players already on it for a single player to join
            def best_to_join
                servers = with_participants
                fullest_needing_participants(servers) || emptiest_accepting_participants(servers)
            end

            # Find the best empty server to provision that can immediately start a match with
            # the given number of players.
            def best_to_provision(count)
                without_participants.select{|s| s.min_players <= count && s.max_players > 0 }.max_by(&:max_players)
            end

            # Find the empty server with the lowest number of required players,
            # which is presumably the next one that will be provisioned.
            def next_to_provision
                without_participants.select{|s| s.max_players > 0 }.min_by(&:min_players)
            end
        end # ClassMethods

        def arena
            game.arena(datacenter) if game?
        end

        # Can queued players wait on this server?
        def waiting_room?
            lobby?
        end
        alias_method :waiting_room, :waiting_room?

        def can_join?
            current_match && (!current_match.started? || current_match.ended? || current_match.join_mid_match)
        end

        def participants
            tickets.map(&:user)
        end

        def participants_needed
            min_players - tickets.count
        end

        def participants_acceptable
            max_players - tickets.count
        end

        def should_requeue?
            if game?
                count = tickets.count
                0 < count && count < min_players
            end
        end

        # Requeue all tickets on this server, and return them
        def requeue_participants!
            ApiSyncable.syncing do
                requeued = tickets.to_a
                unless requeued.empty?
                    tickets.requeue!
                    reload
                    arena.process_queue!
                    api_sync!
                end
                requeued.map(&:reload)
            end
        end
    end # Games
 end
