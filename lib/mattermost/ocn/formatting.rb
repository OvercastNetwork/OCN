module Mattermost
    module OCN
        module Formatting
            include ::Mattermost::Formatting

            def website_url
                "https://#{ORG::DOMAIN}"
            end

            def avatar_url(user, size: 8)
                "#{Rails.configuration.avatar_base_url}/#{user.uuid}/#{size}@2x.png"
            end

            def user_profile_url(user)
                "#{website_url}/#{user.username}"
            end

            def user_teleport_url(user)
                "#{user_profile_url(user)}/tp"
            end

            def user_link(user, url)
                "![](#{avatar_url(user)}) [#{user.username}](#{url})"
            end

            def user_profile_link(user)
                user_link(user, user_profile_url(user))
            end

            def user_teleport_link(user)
                user_link(user, user_teleport_url(user))
            end

            def server_teleport_url(server)
                "#{website_url}/play/#{server.portal.short_name.downcase}/#{server.name}/tp"
            end
        end
    end
end
