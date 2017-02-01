module Admin
    class ChartsController < BaseController
        def index
        end

        # Response format:
        #
        # {
        #     columns: [{name: "..."}, ...],
        #     rows: [[k0, *row0], [k1, *row1], ...]
        # }
        def data
            slices = int_param(:slices)
            charts = params[:charts].to_a
            interval = (time_param(:begin) || key_boundary(charts, false))..(time_param(:end) || key_boundary(charts, true))

            if interval.delta / slices >= 1.day
                # If sample points are more than one day apart, just interpolate
                intervals = interval.subdivide(slices)
            else
                # If sample points are less than one day apart, return a point for each day within the interval
                intervals = []
                today = interval.begin.utc.midnight
                while today < interval.end
                    tomorrow = today.tomorrow.utc.midnight
                    intervals << (today..tomorrow)
                    today = tomorrow
                end
            end

            intervals = intervals.to_a

            json = {columns: [{name: "Time", type: "datetime"}]}
            data = []

            charts.each do |chart|
                name, values = chart_data(chart, intervals)
                json[:columns] << {name: name, type: "number"}
                data << values
            end

            json[:rows] = intervals.map do |interval|
                [interval.lerp(0.5), *data.map{|values| values[interval.begin] || 0 }]
            end

            render json: json
        end

        protected

        # Returns [name, default, {k0 => v0, k1 => v1, ...}]
        def chart_data(name, intervals)
            case name.to_s.to_sym
                when :revenue
                    ["Daily Revenue", Couch::Transaction.revenue(keys: intervals).mash do |interval, revenue|
                        [interval.begin, revenue / 100.0 / [interval.delta.to_i.seconds.in_days, 1].max]
                    end]

                when :players
                    ["Online Players", Couch::Metric.maximum_players(keys: intervals).mash do |interval, players|
                        [interval.begin, players]
                    end]

                else
                    []
            end
        end

        def key_boundary(charts, descending)
            keys = charts.map do |chart|
                case chart.to_s.to_sym
                    when :revenue
                        Couch::Transaction.first_view_key(:total_revenue, descending: descending)

                    when :players
                        Couch::Metric.first_view_key(:aggregate_players, descending: descending)
                end
            end.compact

            if descending
                keys.max
            else
                keys.min
            end
        end
    end
end
