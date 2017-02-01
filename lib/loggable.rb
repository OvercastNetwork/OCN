# A thing with a logger (we could probably do more with this)
module Loggable
    extend ActiveSupport::Concern
    
    included do
    end # included do
    
    module ClassMethods
        def logger
            Logging.logger(default: @logger || Rails.logger)
        end

        def logger=(logger)
            @logger = logger
        end
    end # ClassMethods

    def logger
        Logging.logger(default: @logger || self.class.logger)
    end

    def logger=(logger)
        @logger = logger
    end
end
