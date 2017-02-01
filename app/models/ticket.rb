class Ticket
    include Mongoid::Document
    store_in :database => 'oc_tickets'

    include Mongoid::Timestamps
    include BackgroundIndexes
    include ApiModel
    include ApiSyncable

    EXPIRE = 10.seconds

    belongs_to :user, validates: {presence: true}
    belongs_to :arena, validates: {presence: true}
    belongs_to :server
    field :dispatched_at, type: Time

    props = [:user, :user_id, :arena, :arena_id, :server, :server_id, :dispatched_at]
    attr_accessible *props

    api_property :arena_id, :server_id, :dispatched_at

    api_synthetic :user do
        user.api_player_id
    end

    index(INDEX_user = {user_id: 1}, {unique: true})
    index(INDEX_arena_server = {arena_id: 1, server_id: 1, created_at: 1})
    index(INDEX_server = {server_id: 1})

    field_scope :user, :arena, :server

    scope :playing, -> { ne(server_id: nil) }
    scope :queued, -> { where(server_id: nil) }

    delegate :game, :datacenter, to: :arena

    class << self
        def for_user(user)
            self.user(user).hint(INDEX_user).first
        end

        def cancel!(user)
            res = for_user(user) and res.cancel!
        end

        def requeue!
            each(&:requeue!)
        end

        def expire!(now = Time.now)
            Arena.processing_queue do
                lt(dispatched_at: now - EXPIRE).each(&:expire!)
            end
        end
    end

    def queued?
        server_id.nil?
    end

    def dispatched?
        !queued?
    end

    def arrived?
        dispatched? && dispatched_at.nil?
    end

    def dispatch!(server)
        self.server = server
        if server == user.current_server
            Logging.logger.info "#{user.username} is already on #{server.bungee_name} to play #{game.name}"
            self.dispatched_at = nil
        else
            Logging.logger.info "Dispatching #{user.username} to #{server.bungee_name} to play #{game.name}"
            self.dispatched_at = Time.now
        end
        save!
        server.api_sync!
    end

    def arrive!
        if dispatched? && !arrived?
            Logging.logger.info "User #{user.username} arrived on #{server.bungee_name} to play #{game.name}"
            self.dispatched_at = nil
            save!
        end
    end

    def cancel!
        Logging.logger.info "User #{user.username} cancelled ticket to play #{game.name}"
        arena = self.arena
        destroy!
        arena.process_queue!
    end

    def expire!(now = Time.now)
        if dispatched_at? && dispatched_at + EXPIRE < now
            Logging.logger.info "User #{user.username} did not arrive on #{server.bungee_name} within #{EXPIRE.to_i} seconds"
            cancel!
            arena.process_queue!
        end
    end

    def requeue!
        server = self.server
        self.server = self.dispatched_at = nil
        save!
        server.api_sync! if server
    end
end
