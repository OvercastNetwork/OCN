class Server
    module Maps
        extend ActiveSupport::Concern
        include Deployment
        
        included do
            # Directory of this server's local maps repository
            field :local_maps_path, type: String
        end # included do

        module ClassMethods
            def for_maps_branch(branch)
                Server.find_by(name: branch)
            end
        end

        def local_maps_path
            self[:local_maps_path] || "#{deploy_path}/maps"
        end
    end # Maps
 end
