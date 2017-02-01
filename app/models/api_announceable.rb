# A model that announces creation of new instances on the topic exchange,
# but does not announce any subsequent changes.
module ApiAnnounceable
    extend ActiveSupport::Concern
    include ApiModel
    
    included do
        after_create :api_announce!
    end # included do

    def api_announce!
        publish_announce_message
    end

    def publish_announce_message
        Publisher::TOPIC.publish_topic(ModelUpdate.new(self))
    end
end
