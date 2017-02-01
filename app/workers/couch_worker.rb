require 'open-uri'

# Listens to the CouchDB changes feed and syncs things with Mongo
class CouchWorker
    include Worker

    startup do
        # Get current sequence number
        begin
            @last_seq = Couch::MapRating.score_by_map.get_changes(since: 'now')['last_seq'].to_i
        rescue RestClient::RequestTimeout
            # No way to configure the timeout in CouchRest, so we have to do this
            retry
        end

        # Sync all maps
        Map.all.sync_ratings

        logger.info "Listening for map rating changes from seq #{@last_seq}"

        # Listen for changes starting at the sequence number from before the sync
        @polling_thread = Thread.new do
            while running?
                if changes = poll_for_changes
                    schedule do
                        map_ids = changes['results'].map{|result| result['doc'].map_id }
                        Map.where(:id.in => map_ids).sync_ratings
                    end
                end
            end
        end
    end

    def poll_for_changes
        begin
            changes = Couch::MapRating.score_by_map.get_changes(
                feed: 'longpoll',
                since: @last_seq || 'now',
                include_docs: true,
            )
            @last_seq = changes['last_seq'].to_i
            changes
        rescue RestClient::RequestTimeout
            # No way to configure the timeout in CouchRest, so we have to do this
            retry
        rescue Interrupt
            # normal exit
        end
    end

    def stop
        super
        @polling_thread.raise Interrupt if @polling_thread
    end
end
