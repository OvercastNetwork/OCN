module Channel
    class Base
        include Mongoid::Document
        include Mongoid::Timestamps
        include BackgroundIndexes
        include DisablePolymorphism

        store_in database: 'oc_channels', collection: 'channels'

        field :service, type: String
        field :name, type: String
        field :thumbnail_url, type: String

        field :videos, type: Integer
        field :views, type: Integer
        field :subscribers, type: Integer

        field :refreshed_at, type: Time

        has_and_belongs_to_many :users

        validates_presence_of :name
        validates_inclusion_of :service, in: ['youtube']

        index({refreshed_at: 1})
        index({service: 1})
        index({videos: 1})
        index({views: 1})
        index({subscribers: 1})
        index({user_ids: 1})

        class << self
            def class_for_service(service)
                case service
                    when 'youtube'
                        Channel::Youtube
                    else
                        self
                end
            end

            def instantiate(attrs = nil, *args)
                service = attrs['service']
                if self == Base && service && klass = class_for_service(service)
                    klass.instantiate(attrs, *args)
                else
                    super
                end
            end

            def refresh!(channels = all.to_a)
                channels.each(&:refresh!)
            end
        end

        # Fetch latest details from respective service and save the channel
        # If the service says the channel does not exist, delete it
        def refresh!

        end

        # Link to channel page
        def url

        end
    end
end
