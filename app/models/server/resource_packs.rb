class Server
    module ResourcePacks
        extend ActiveSupport::Concern

        included do
            belongs_to :resource_pack

            # true -> send new respack to players immediately
            # false -> send new respack to players only on map cycle
            field :resource_pack_fast_update, type: Boolean, default: false

            attr_cloneable :resource_pack, :resource_pack_fast_update

            api_property :resource_pack_fast_update

            api_synthetic :resource_pack_url do
                resource_pack.url if resource_pack?
            end

            api_synthetic :resource_pack_sha1 do
                resource_pack.sha1 if resource_pack?
            end
        end # included
    end # ResourcePacks
end
