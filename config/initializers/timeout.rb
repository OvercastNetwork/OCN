Rack::Timeout.timeout = 30
Rack::Timeout.unregister_state_change_observer(:logger)
