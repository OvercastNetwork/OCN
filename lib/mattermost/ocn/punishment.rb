module Mattermost
    module OCN
        class Punishment < ::Mattermost::OCN::Post
            attr :punishment

            def initialize(punishment)
                @punishment = punishment
            end

            def username
                case punishment.type
                    when ::Punishment::Type::WARN
                        "Warning"
                    when ::Punishment::Type::KICK
                        "Kick"
                    when ::Punishment::Type::BAN
                        punishment.expire? ? "Ban" : "Permaban"
                    else
                        punishment.description.capitalize
                end
            end

            def text
                t = ''
                if server = punishment.server
                    t << "**[[#{server.datacenter} #{server.name}](#{server_teleport_url(server)})]** "
                end
                if punisher = punishment.punisher
                    t << " #{user_link(punisher)}"
                end
                t << " #{punishment.past_tense_verb} #{user_link(punishment.punished)}"
                if punishment.expire?
                    t << " for #{(Time.now - punishment.expire).seconds.in_days.round} days"
                end
                t << " for *#{punishment.reason}*"
                t
            end

            def post
                ::Mattermost::OCN::Report::HOOK.post(self)
            end
        end
    end
end
