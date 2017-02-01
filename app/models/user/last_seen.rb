class User
    module LastSeen
        extend ActiveSupport::Concern

        class Sighting
            include Mongoid::Document
            embedded_in :user, inverse_of: nil

            field :online, type: Boolean, default: false
            field :time, type: Time, validates: {presence: true}, default: -> { Time.now }
            belongs_to :server #, validates: {presence: true} TODO: clean up junk data and enable this
            belongs_to :session #, validates: {presence: true}

            def last_online_at
                if online?
                    Time.now.utc
                else
                    time
                end
            end

            def self.from_session(session)
                new online: session.online?,
                    time: (session.end || session.start).utc,
                    server_id: session.server_id,
                    session_id: session.id
            end
        end

        included do
            embeds_one :last_sighting, class_name: 'User::LastSeen::Sighting'
            embeds_one :last_public_sighting, class_name: 'User::LastSeen::Sighting'

            scope :online, where('last_sighting.online' => true)

            [:last_sighting, :last_public_sighting].each do |a|
                [:online, :time, :server_id].each do |b|
                    index({"#{a}.#{b}" => 1})
                end
            end
        end

        def online?
            (last_sighting && last_sighting.online?).to_bool
        end

        # Update last seen fields from the given session. If the session is finished,
        # and does not match the last started session, ignore it (because adjacent
        # sessions may overlap).
        def update_sightings!(session)
            sighting = Sighting.from_session(session).as_document
            if session.online?
                u = {last_sighting: sighting}
                u.merge!(last_public_sighting: sighting) unless session.disguised_to_anybody?
                where_self.update_all(u)
            else
                where_self.or(
                    {last_sighting: nil},
                    {'last_sighting.online' => false},
                    {'last_sighting.session_id' => session.id}
                ).update_all(last_sighting: sighting)

                where_self.or(
                    {last_public_sighting: nil},
                    {'last_public_sighting.online' => false},
                    {'last_public_sighting.session_id' => session.id}
                ).update_all(last_public_sighting: sighting) unless session.disguised_to_anybody?
            end
        end

        # If either the last_sighting or last_public_sighting fields are not set,
        # search back through the user's sessions and try to fill them in.
        # Calls #save! if either field was changed.
        def find_sightings!
            if last_sighting.nil?
                self.last_sighting = if session = Session.last_started_by(self)
                    Sighting.from_session(session)
                else

                end
            end

            if last_public_sighting.nil? && (session = Session.last_public_started_by(self))
                self.last_public_sighting = Sighting.from_session(session)
            end

            save! if changed?
        end

        def last_sighting_by(viewer = User.current)
            find_sightings!
            if reveal_disguises_to?(viewer)
                last_sighting
            else
                last_public_sighting
            end
        end

        def last_seen_by(viewer = User.current)
            find_sightings!
            if sighting = last_sighting_by(viewer)
                if sighting.online
                    Time.now.utc
                else
                    sighting.time
                end
            else
                Time::INF_FUTURE
            end
        end
    end
end
