class Server
    module Lifecycle
        extend ActiveSupport::Concern
        include ApiModel
        include FormattingHelper # for time_ago_shorthand

        included do
            field :online, type: Boolean, default: false
            field :start_time, type: Time
            field :stop_time, type: Time
            attr_accessible :online, :start_time, :stop_time

            scope :online, where(online: true)
            scope :offline, ne(online: true)

            api_property :online

            define_callbacks :startup, :shutdown, :up_or_down

            around_save do |_, yield_save|
                was_online, is_online = changes['online'].to_a

                if was_online != is_online
                    run_callbacks :up_or_down do
                        if is_online
                            run_callbacks :startup do
                                yield_save.call
                            end
                        else
                            run_callbacks :shutdown do
                                yield_save.call
                            end
                        end
                    end
                else
                    yield_save.call
                end
            end

            before_event :startup do
                self.start_time = Time.now.utc
                true
            end

            before_event :shutdown do
                self.stop_time = Time.now.utc
                true
            end
        end # included do

        module ClassMethods
        end # ClassMethods

        UPTIME_WARNING = 24.hours
        UPTIME_ERROR = 36.hours

        def uptime_text
            if !self.online?
                "Offline"
            elsif self.start_time
                time_ago_shorthand(self.start_time)
            else
                "Online"
            end
        end

        def uptime_color
            if !self.online?
                "status-offline"
            elsif self.start_time
                uptime = Time.now - self.start_time
                if uptime >= UPTIME_ERROR
                    "status-error"
                elsif uptime >= UPTIME_WARNING
                    "status-warning"
                else
                    "status-ok"
                end
            else
                "status-error"
            end
        end
    end # Lifecycle
end
