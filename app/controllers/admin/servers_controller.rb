module Admin
    class ServersController < BaseController
        skip_before_filter :html_only, :only => [:modify]
        before_filter :find_server, only: [:edit, :update, :destroy, :clone]

        def index
            @datacenters = Server.public_datacenters
            @boxes = Box.all.sort_by(&:id)
            @rotations_updated = nil
            @family_ids = []

            @families = [*Family.imap_all.sort_by(&:priority), nil].collect do |family|
                @family_ids << family.id if family

                {
                    id: family && family.id,
                    name: if family then family.name else "No Family :(" end,
                    online_players: 0,
                    online_servers: 0,
                    dynamic_servers: 0,
                    servers: []
                }
            end

            families_by_id = @families.index_by{|f| f[:id] }

            servers_query = if params[:dc]
                                Server.datacenter(params[:dc])
                            else
                                Server.all
                            end.by_datacenter.by_priority

            servers_query.each do |server|
                family = families_by_id[server.family] || families_by_id[nil]

                family[:servers] << server
                family[:dynamic_servers] += 1 if server.dynamics['enabled']

                if server.online?
                    family[:online_servers] += 1
                    family[:online_players] += server.num_online
                end

                if @rotations_updated.nil? || (!server.dynamics["updated"].nil? && server.dynamics["updated"] < @rotations_updated)
                    @rotations_updated = server.dynamics["updated"]
                end
            end

            # Fill cache
            Repository[:plugins].revisions(per_page: 20)
            Repository[:sportbukkit].revisions(per_page: 20)
            Repository[:nextgen].revisions(per_page: 20)
        end

        def new
            @server = Server.new
            breadcrumb "New Server"
        end

        def clone
            Server.without_attr_protection do
                # Mongoid uses #new to clone the model, so it's treated as a mass-assignment
                @server = @server.clone
            end
            render :new
        end

        def create
            @server = Server.new
            update_server
            if @server.valid?
                @server.save
                redirect_to admin_servers_path, alert: "Server created"
            else
                render :new
            end
        end

        def edit
            @dns_record = @server.dns_record if @server.dns_record_id
            breadcrumb @server.name
        end

        def update
            update_server
            if @server.valid?
                @server.save
                redirect_to edit_admin_server_path(@server), alert: "Server updated"
            else
                render :edit
            end
        end

        def destroy
            @server.die!
            redirect_to action: :index
        end

        def sync_dns
            Server.sync_dns_status
            redirect_to action: :index
        end

        def restart_lobbies
            Server.lobbies.queue_rolling_restart
            redirect_to admin_servers_path, alert: "Queued rolling restart of all lobbies"
        end

        helper do
            # Convert time span to pixel width for DSN schedule display
            def duration_px(t)
                t / 10.minutes
            end

            def revision_class(rev)
                if rev.latest?
                    'status-ok'
                else
                    'status-warning'
                end
            end

            def revision(rev)
                if rev
                    %[<div rel="tooltip" class="#{revision_class(rev)}" title="#{h(rev.message)}">#{h(rev.sha_brief)}</div>].html_safe
                end
            end
        end

        private
        def find_server
            not_found unless @server = Server.find(params[:id])
            @dns_window_start = format_time_of_day(@server.dns_window_start)
            @dns_window_stop = format_time_of_day(@server.dns_window_stop)
        end

        def update_server
            server = params[:server]

            server[:realms] = server[:realms].split

            server["dynamics"]["enabled"] = server["dynamics"]["enabled"].parse_bool
            server["dynamics"]["order"]   = server["dynamics"]["order"].to_i
            server["dynamics"]["size"]    = server["dynamics"]["size"].to_i

            %w{dns_record_id update_server_path rotation_file team_id tournament_id ip}.each do |f|
                server[f] = nil if server[f].blank?
            end

            %w[dns_window_start dns_window_stop].each do |f|
                server[f] = parse_time_of_day(server[f])
            end

            server[:operator_ids] = server[:operator_ids].split(/,/)
            server[:resource_pack] = ResourcePack.find(server[:resource_pack_id]) unless server[:resource_pack_id].blank?

            @server.without_attr_protection do
                @server.update_attributes!(server)
            end
        end
    end
end
