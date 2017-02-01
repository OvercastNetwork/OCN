module Couch
    class Transaction
        include CouchPotato::Persistence
        include CouchHelper

        self.database_name = 'ocn_transactions'

        property :payer_id, type: String
        property :package_id, type: String
        property :cents, type: Fixnum

        class << self
            def from_mongo(trans)
                new(_id: "Transaction:#{trans.id}",
                    created_at: trans.created_at,
                    updated_at: trans.updated_at,
                    payer_id: trans.user_id.to_s,
                    package_id: trans.purchase.package.id.to_s,
                    cents: trans.total.to_i)
            end

            def import_mongo(docs)
                total = docs.count
                docs.each_with_index do |doc, i|
                    tries = 0
                    begin
                        puts "Transaction #{doc.id} (#{i + 1}/#{total})"
                        couch_doc = from_mongo(doc)
                        if doc.payed?
                            couch_doc.save!(conflict: :ours)
                        else
                            couch_doc.destroy
                        end
                    rescue Errno::EADDRNOTAVAIL # This is raised intermittently, no clue why
                        tries += 1
                        retry if tries < 10
                    end
                end
            end

            def revenue(**args)
                query(total_revenue(reduce: true), **args)['rows'].map do |row|
                    [row['key_range'], row['value']['sum']]
                end
            end

            def latest
                rows = query(total_revenue(reduce: false, descending: true, limit: 1))['rows']
                if rows.empty?
                    Time::INF_PAST
                else
                    Time.json_create(rows[0]['key']).utc
                end
            end
        end

        class TotalRevenueView < CouchPotato::View::BaseViewSpec
            def map_function
                <<-JS
                    function(doc) {
                        if(doc.ruby_class === "Couch::Transaction") {
                            emit(doc.created_at, doc.cents);
                        }
                    }
                JS
            end

            def reduce_function
                '_stats'
            end
        end

        view :total_revenue, type: TotalRevenueView
    end
end
