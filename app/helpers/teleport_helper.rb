module TeleportHelper
    include UserHelper::Global

    def server_teleport_path(server)
        url_for controller: 'play',
                action: 'teleport',
                portal: server.portal.short_name.downcase,
                server: server.name
    end

    def user_teleport_path(user)
        "#{user_path(user)}/tp"
    end

    def teleport_path(thing)
        case thing
            when Server
                server_teleport_path(thing)
            when User
                user_teleport_path(thing)
        end
    end

    def teleport_button(thing)
        case thing
            when Server
                tip = "Connect to #{thing.name}"
            when User
                tip = "Teleport to #{thing.username}"
        end

        html = <<-HTML
            <a href="#{teleport_path(thing)}" class="tp-button" rel="tooltip" title="#{tip}"><i class="fa fa-play"></i></a>
        HTML
        html.html_safe
    end
end
