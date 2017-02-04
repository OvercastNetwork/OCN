class Server
    module Rotations
        extend ActiveSupport::Concern
        include RequestCacheable

        included do
            # {
            #     rotation_name => {
            #         "maps" => [map_name, map_name, ...],
            #         "next" => map_index
            #     }
            # }
            field :rotations, type: Hash

            field :rotation_file, type: String # relative to rotations repo root

            blank_to_nil :rotation_file
            attr_cloneable :rotations, :rotation_file

            # Lines from the rotation file, if any
            attr_cached :rotation_entries do
                if fn = rotation_path and File.exists?(fn)
                    File.read(fn).lines
                else
                    []
                end
            end

            # Ids of maps from all server rotations
            cattr_cached :rotation_map_ids do
                if self == Server
                    all.flat_map(&:rotation_map_ids).uniq
                else
                    # Don't want this called on a Criteria since it's cached
                    Server.rotation_map_ids
                end
            end
        end # included do

        def rotation_path
            if repo = Repository[:rotations]
                repo.join_path(rotation_file || File.join(datacenter, name))
            end
        end

        def rotation_map_ids
            rotation_entries.map{|entry| Map.id_from_rotation(entry) }
        end

        # Return Map objects in the rotation, in the correct order
        def rotation_maps(maps = Map)
            maps.from_rotation(*rotation_entries)
        end

        module ClassMethods
            # All rotation maps
            def rotation_maps(maps = Map)
                maps.in(id: rotation_map_ids)
            end
        end
    end # Rotations
end
