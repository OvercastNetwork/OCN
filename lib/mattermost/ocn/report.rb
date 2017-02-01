module Mattermost
    module OCN
        class Report < ::Mattermost::OCN::Post
            HOOK = Mattermost::Hook.new('r4siz65pdpgfze4y9ox9wcqs7r')

            attr :report

            def initialize(report)
                @report = report
            end

            def username
                if report.scope == 'web'
                    "Web Report"
                else
                    "Server Report"
                end
            end

            def text
                t = ''
                if server = report.server
                    staff = report.staff_online.size
                    t << "**[[#{server.datacenter} #{server.name}](#{server_teleport_url(server)})] [#{staff > 0 ? staff : 'NO STAFF'}]** "
                end
                t << user_teleport_link(report.reporter)
                t << if report.scope == 'web'
                    " [reported](#{website_url}/reports/#{report.id}) "
                else
                    " reported "
                end
                t << "#{user_teleport_link(report.reported)} for *#{report.reason}*"
                t
            end

            def post(sync: false)
                HOOK.post(self, sync: sync)
            end
        end
    end
end
