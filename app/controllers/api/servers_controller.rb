require 'string_scorer'

module Api
    class ServersController < ApiController

        before_filter :find_server, only: [:show, :notify_startup, :notify_shutdown, :update]
        before_filter :filter_servers, only: [:index, :search, :staff]

        protected

        def find_server
            raise NotFound unless @server = Server.find(params[:id])
        end

        def filter_servers
            @servers = Server.search(params)
        end

        def respond_to_search
            respond_with_message Server.search_response(documents: @servers)
        end

        public

        def show
            respond(@server.api_document)
        end

        def search
            respond_to_search
        end

        def by_name
            name_search = params[:name_search]
            safe_score = 0.9 # score above which the match is considered safe

            # use LiquidMetal algorithm to rank servers based on score
            results = Server.searchable.datacenter(params[:datacenter]).map do |s|
                { :server => s, :score => s.name.score(name_search) }
            end
            .select { |result| result[:score] >= safe_score }
            .sort { |a, b| b[:score] <=> a[:score] }

            # if there are public servers matched we need to prefer them over other
            # matches in order to prevent leaking the name of unlisted servers
            public_results = results.select { |result| result[:server].visible_to_public? }
            results = public_results if public_results.any?

            # unlisted servers should not be listed so we won't let the
            # client disambiguate among them
            results = [] if results.count > 1 && public_results.empty?

            @servers = Server.in(id: results.map{|r| r[:server].id })
            respond_to_search
        end

        def metric
            field = DateTime.now.strftime('%Y-%m-%d') + "." + params[:type]
            begin
                BungeeMetric.collection.find(_id: params[:ip]).update_one({$inc => {field => 1}}, {upsert: true})
            rescue Mongo::Error::OperationFailure => ex
                # Ignore bogus error that happens here a lot
                # https://jira.mongodb.org/browse/SERVER-20829
                raise unless ex.message =~ /RUNNER_DEAD/
            end
            respond
        end

        def update
            attrs = params.require(:document)
            @server.update_relations!(attrs)
            @server.update_attributes!(attrs)
            show
        end

        def ping
            vhost = params[:vhost]

            server = Server.find_by({:virtual_hosts => vhost}) or raise NotFound

            response = {
                slots: server.settings['slots'],
            }

            pool_server = server.pool_server
            if pool_server.present?
                response['players'] = pool_server.sessions.online.count
                response['motd'] = "Now playing: " + pool_server.current_map_name
            else
                response['players'] = 0
                response['motd'] = "Currently offline" # todo
            end

            respond(response)
        end
    end
end
