module Couch
    class Metric
        include CouchPotato::Persistence
        include CouchHelper

        self.database_name = 'ocn_metrics'

        INTERVAL = 1.hour
        SEARCH_BACK = 24.hours # Look this far back for sessions that overlap the interval being imported

        property :time, type: Time
        property :players, type: Fixnum

        derived_property :id do
            self.class.make_id(time) if time
        end

        def normalize
            super
            self.time = self.time.getutc
        end

        class PlayersView < CouchPotato::View::BaseViewSpec
            def map_function
                <<-JS
                    function(doc) {
                        if(doc.ruby_class === "Couch::Metric") {
                            emit(doc.time, doc.players);
                        }
                    }
                JS
            end

            def reduce_function
                '_stats'
            end
        end
        view :aggregate_players, type: PlayersView

        class << self
            def make_id(time)
                time.getutc.strftime("Metric:%Y-%m-%d %H:%M:%S")
            end

            def process_view_args(args)
                if args.has_key?(:keys)
                    args[:keys] = args[:keys].map do |key|
                        if key.is_a?(Range) && key.delta < INTERVAL
                            key.begin..(key.begin + INTERVAL)
                        else
                            key
                        end
                    end
                end
            end

            def average_players(**args)
                process_view_args(args)
                query(aggregate_players(reduce: true), **args)['rows'].map do |row|
                    [row['key_range'], row['value']['sum'] / row['value']['count']]
                end
            end

            def maximum_players(**args)
                process_view_args(args)
                query(aggregate_players(reduce: true), **args)['rows'].map do |row|
                    [row['key_range'], row['value']['max']]
                end
            end
        end

        class Importer
            def initialize(sessions: Session.all, step: INTERVAL, logger: Rails.logger)
                @sessions = sessions
                @step = step
                @slices = {}
                @logger = logger
            end

            def slice(time)
                @slices[time.to_i] ||= Metric.new(time: time, players: 0)
            end

            def save_slice(slice)
                @logger.info "Importing metric: at #{slice.time} there were #{slice.players} players online"

                @slices.delete(slice.time.to_i)
                slice.save(conflict: :ours)
            end

            def save_slices(before: Time::INF_FUTURE)
                @slices.values.select{|slice| slice.time < before }.each{|slice| save_slice(slice) }
            end

            def first_step_after(t)
                Time.at(t.to_i + (-t.to_i % @step)).getutc
            end

            def last_step_before(t)
                Time.at(t.to_i - (t.to_i % @step)).getutc
            end

            # Generate metrics for every time step within the given interval
            def import_interval(interval)
                # Start looking for sessions 24h before the start of the interval.
                # (there does not seem to be any efficient query to find all sessions
                # that cover a given point in time, so this is the best we can do)
                @sessions.gte(start: interval.begin - SEARCH_BACK).lt(start: interval.end).asc(:start).each do |session|
                    # Flush any sample points earlier than the start of the current session
                    save_slices(before: session.interval.begin)

                    # Cycle through all sample points within both the session and
                    # the interval parameter, and increment the player count for each.
                    i = interval.intersect(session.interval)
                    time = first_step_after(i.begin)

                    while i.cover?(time)
                        slice(time).players += 1
                        time += @step
                    end
                end
            end
        end
    end
end
