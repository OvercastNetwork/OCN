class Server
    module Matches
        extend ActiveSupport::Concern
        include Lifecycle

        included do
            # Mongoid demands exclusive use of the word "matches"
            has_many :fucking_matches, class_name: 'Match', inverse_of: :server
            belongs_to :current_match, class_name: 'Match', inverse_of: :server
            accepts_nested_attributes_for :current_match # Allow current match to be updated through its server

            has_many :participations

            belongs_to :current_map, class_name: 'Map', inverse_of: nil
            field :current_map_name, type: String
            belongs_to :next_map, class_name: 'Map', inverse_of: nil
            accepts_nested_attributes_for :next_map
            field :next_map_name, type: String

            attr_accessible :current_match, :next_map, :next_map_id

            api_property :current_match, :next_map

            before_validation do
                if pgm? && (current_match.nil? || current_match.unloaded?)
                    # Try to find current_match if its missing
                    self.current_match = fucking_matches.criteria.loaded.desc(:load).first
                end

                self.current_map = current_match.map if current_match
                self.current_map_name = current_map.name if current_map
                self.next_map_name = next_map.name if next_map
                true
            end

            before_event :shutdown do
                self.current_match = nil
                self.current_map = nil
                self.next_map = nil

                participations.finish
                fucking_matches.unload!
                true
            end
        end # included do

        module ClassMethods
            def left_join_next_maps(maps = Map.all, servers: all)
                servers = servers.to_a
                maps = maps.in(id: servers.map(&:next_map_id).compact)
                maps_by_id = maps.index_by(&:id)

                servers.each do |server|
                    if map = maps_by_id[server.next_map_id]
                        server.set_relation(:next_map, map)
                    end
                end

                servers
            end
        end # ClassMethods
    end # Matches
end
