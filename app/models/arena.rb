class Arena
    include Mongoid::Document
    store_in :database => Server::DATABASE_NAME

    include ApiModel
    include ApiSyncable

    belongs_to :game
    field :datacenter, type: String
    field :num_playing, type: Integer, default: 0
    field :num_queued, type: Integer, default: 0

    # Every time the queue is processed, it chooses the next empty server
    # to be provisioned and saves a reference here. If no empty servers
    # are available, this will be set to nil. This can be used to determine
    # what map will be played, and how many players are required.
    belongs_to :next_server, class_name: 'Server'

    has_many :tickets

    field_scope :game, :datacenter

    validates_presence_of :game, :datacenter, :num_playing, :num_queued

    api_property :game_id, :datacenter, :num_playing, :num_queued, :next_server_id

    delegate :name, :network, to: :game

    PROCESS_QUEUE = ThreadLocal.new

    class << self
        def processing_queue(&block)
            PROCESS_QUEUE.debounce(init:  -> { Set[] },
                                   after: -> (arenas) { arenas.each(&:process_queue!) },
                                   &block)
        end
    end

    def servers
        game.servers.where(datacenter: datacenter)
    end

    def tickets_queued
        tickets.queued.asc(:created_at).hint(Ticket::INDEX_arena_server)
    end

    def tickets_playing
        tickets.playing.asc(:created_at).hint(Ticket::INDEX_arena_server)
    end

    def process_queue!
        if PROCESS_QUEUE.present?
            PROCESS_QUEUE.get << self
        else
            ApiSyncable.syncing do
                servers = self.servers.online.asc(:priority)

                # Fill any vacant slots on servers that are already partly filled,
                # by pulling players out of the queue one at a time
                while ticket = tickets_queued.first and server = servers.best_to_join
                    ticket.dispatch!(server)
                    server.api_sync!
                end

                # Provision new servers as long as there are enough queued players
                # for them to start a match right away.
                while (self.num_queued = tickets_queued.count) > 0 and server = servers.best_to_provision(num_queued)
                    count = [num_queued, server.max_players].min

                    Logging.logger.info "Provisioning server #{server.name} for #{count} players to play #{name}"

                    count.times do
                        tickets_queued.first.dispatch!(server)
                    end

                    server.api_sync!
                end

                self.num_playing = tickets_playing.count
                self.next_server = servers.next_to_provision
                save!
            end
        end
    end

    def enqueue!(user)
        Ticket.cancel!(user)
        Logging.logger.info "User #{user.username} joining queue for #{name}"
        ticket = tickets_queued.user(user).create!
        process_queue!
        ticket
    end
end
