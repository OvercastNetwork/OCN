module ApiSyncable
    extend ActiveSupport::Concern
    include ApiModel
    include ApiSearchable

    included do
        after_save :api_sync!
        after_destroy :api_sync!
    end

    def api_sync!
        if SYNC_QUEUE.present?
            SYNC_QUEUE.get.delete(self).add(self)
        else
            publish_sync_message
        end
    end

    def publish_sync_message
        Publisher::TOPIC.publish_topic(destroyed? ? ModelDelete.new(self) : ModelUpdate.new(self))
    end

    SYNC_QUEUE = ThreadLocal.new

    class << self
        def syncing(&block)
            SYNC_QUEUE.debounce(init: -> { Set[] },
                                after: -> (docs) { docs.each(&:api_sync!) },
                                &block)
        end
    end # ClassMethods
end
