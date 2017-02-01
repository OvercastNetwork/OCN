class ChartWorker
    include Worker

    poll interval: 1.hour do
        interval = (@now || 1.hour.ago.utc)..Time.now.utc
        @now = interval.end

        Couch::Metric::Importer.new(logger: logger).import_interval(interval)
        Couch::Transaction.import_mongo(Transaction.gte(updated_at: interval.begin))
    end
end
