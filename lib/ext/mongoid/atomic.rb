module Mongoid
    module Atomic
        # Monkey-patch a bug where embedded field names end up as
        # empty strings in update queries.
        def atomic_paths
            if @atomic_paths
                @atomic_paths
            elsif __metadata
                @atomic_paths = __metadata.path(self)
            else
                @atomic_paths_root ||= Atomic::Paths::Root.new(self)
            end
        end
    end
end
