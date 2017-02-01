module ServerHelper
    def server_name(server, global: true)
        if global
            "#{server.name} <small>(#{server.portal.short_name})</small>".html_safe
        else
            server.name.html_safe
        end
    end

    def match_length(match)
        state = if match.end
                    'match-finished'
                elsif match.start
                    'match-running'
                else
                    'match-starting'
                end
        content_tag :span, match.length, class: state
    end
end
