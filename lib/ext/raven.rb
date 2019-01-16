module Ext
    module Raven
        if Object::const_defined? :Raven
            class HttpInterface < ::Raven::HttpInterface
                name 'request'

                def from_rack(env)
                    # ActionDispatch::ShowExceptions changes PATH_INFO to the error page
                    # before it gets here, so we need to change it back.
                    if original_path = env['action_dispatch.original_path']
                        env = env.merge('PATH_INFO' => original_path)
                    end
                    super(env)
                end
            end
        end

        module ClassMethods
            def capture_event(event)
                yield event if block_given?
                if configuration.async?
                    configuration.async.call(event)
                else
                    send_event(event)
                end
            end

            # Raise an error in development, send an alert in production
            def non_fatal(message)
                ex = RuntimeError.new(message)
                if configuration.current_environment == 'production'
                    begin
                        raise ex
                    rescue => e
                        capture_exception(e)
                    end
                else
                    raise ex
                end
            end

            def send_event_async(event)
                Thread.new do
                    begin
                        BacktraceCleaners.clean_raven_event(event)

                        10.times do |i|
                            if send_event(event)
                                break
                            else
                                logger.warn "Failed to send error to Sentry (try ##{i + 1})"
                            end
                        end
                    rescue => ex
                        logger.error "Raven async send thread: #{ex.format_long}"
                    end
                end
            end
        end
    end
end

if Object::const_defined? :Raven
    ::Raven.extend(::Ext::Raven::ClassMethods)

    # This should replace the one already registered
    ::Raven.register_interface http: ::Ext::Raven::HttpInterface
end
