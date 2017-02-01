class Server
    module Sessions
        extend ActiveSupport::Concern
        include Lifecycle

        included do
            has_many :sessions

            scope :sessions, -> (s) { self.in(id: s.map(&:server_id)) }

            before_event :up_or_down do
                sessions.finish_all!
                true
            end
        end # included do

        module ClassMethods
            # Run this query and return an array of Servers, with Sessions joined in
            # from the given set, and merged into the #joined_sessions of each Server
            # returned. If the sessions are given as a Criteria, they will filtered
            # down to those belonging to these servers, and fetched in a single query.
            def left_join_sessions(sessions, servers: all)
                servers = servers.to_a
                servers_by_id = servers.index_by(&:id)

                sessions = sessions.servers(servers) if sessions.respond_to?(:servers)

                sessions.each do |session|
                    if server = servers_by_id[session.server_id]
                        session.set_relation(:server, server)
                        server.joined_sessions << session
                    end
                end

                servers
            end
        end # ClassMethods

        def joined_sessions
            @joined_sessions ||= []
        end
    end # Sessions
end
