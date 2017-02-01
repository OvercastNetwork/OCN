class MongoProfileWorker
    include Worker

    TOO_LONG_MS = 2000

    startup do
        Rails.application.eager_load! # Force all models to load
    end

    startup do
        @latest_seen = Mongoid.models.map do |model|
            mp = MongoProfile.with_model(model).desc(:ts).first and mp.ts
        end.compact.max || Time::INF_PAST

        logger.info "Watching for slow queries after #{@latest_seen}"
    end

    poll delay: 10.seconds do
        Mongoid.models.each do |model|
            MongoProfile.with_model(model).gte(millis: TOO_LONG_MS).gt(ts: @latest_seen).asc(:ts).each do |mp|
                @latest_seen = mp.ts
                msg = "#{model} #{mp.op} took #{mp.millis}ms: #{(mp.query || mp.command).to_json}"
                logger.warn msg
                Raven.capture_message(msg, extra: {document: JSON.pretty_unparse(mp.as_document)})
            end
        end
    end
end
