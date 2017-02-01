class Server
    # This is just some extra API fields that are sent to Bungees
    # on startup. They are global values, and don't even read anything
    # from the Server document, so they should probably be moved somewhere else.
    module Bungees
        extend ActiveSupport::Concern
        
        included do
            api_synthetic :banners do
                if bungee?
                    Banner.active.map do |banner|
                        { weight: banner.weight,
                          rendered: banner.render(datacenter) }
                    end
                else
                    []
                end
            end

            api_synthetic :fake_usernames do
                # Needs optimizing
                # User.where(:fake_username.ne => nil).mash{|u| [u.uuid, u.fake_username] },
                {}
            end
        end # included do
    end # Bungees
 end
