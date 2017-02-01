module ActiveSupport
    class Duration
        def in_days
            in_hours / 24.0
        end

        def in_hours
            in_minutes / 60.0
        end

        def in_minutes
            in_seconds / 60.0
        end

        def in_seconds
            value
        end

        def in_milliseconds
            value * 1000
        end

        def as_json(options = nil)
            value.as_json(options)
        end

        def mongoize
            in_milliseconds
        end

        def class
            # Mongo needs this to access the serialization methods through an instance e.g.
            #
            #     t.class.evolve(t)
            #
            # Unfortunately, it will return the wrong result from a subclass.
            Duration
        end

        class << self
            def demongoize(ms)
                (ms / 1000.0).seconds if ms
            end

            def mongoize(duration)
                case duration
                    when Duration then duration.mongoize
                    else duration
                end
            end

            def evolve(duration)
                mongoize(duration)
            end
        end
    end
end
