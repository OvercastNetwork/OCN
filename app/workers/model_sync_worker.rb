# Currently unused
class ModelSyncWorker
    include Worker

    SHARDS = ['localhost:27017']

    def tail_oplog(uri)
        oplog = Mongo::Client.new([uri]).use('local')['oplog.rs']
        ts = oplog.find.sort('$natural' => -1).limit(1).first['ts']

        logger.info "Tailing oplog on #{uri} from timestamp #{Time.at(ts.seconds).utc}"

        while running?
            view = oplog.find({ts: {$gt => ts}, fromMigrate: {$exists => false}},
                              cursor_type: :tailable_await)
            view.each do |doc|
                schedule{ handle_change(doc) }
            end
        end
    end

    def handle_change(doc)
        time = Time.at(doc['ts'].seconds).utc
        q = doc['o']

        case doc['op']
            when 'i'
                command = "INSERT"
                id = q['_id']
            when 'u'
                command = "UPDATE"
                id = doc['o2']['_id']
            when 'd'
                command = "DELETE"
                id = q['_id']
            else
                command = "???: #{doc['op']}"
                id = nil
        end

        model = Mongoid.models.find{|m| m.collection.namespace == doc['ns'] } || '???'

        logger.info "#{time} #{command} #{model}[#{id}]"
    end

    startup do
        Rails.application.eager_load! # Force all models to load

        @threads = SHARDS.map do |uri|
            Thread.new{ tail_oplog(uri) }
        end
    end

    shutdown do
        @threads && @threads.each(&:kill)
    end
end
