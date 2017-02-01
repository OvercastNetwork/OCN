
# Base class for AMQP messages
class BaseMessage
    Meta = Struct.new(:content_type, :content_encoding, :headers, :delivery_mode, :priority, :correlation_id,
                      :reply_to, :expiration, :message_id, :timestamp, :type, :user_id, :app_id, :cluster_id)

    Delivery = Struct.new(:consumer_tag, :delivery_tag, :redelivered, :exchange, :routing_key)

    # Default value for the app_id metadata field
    APP_ID = 'ocn'

    attr_reader :payload        # Content of the message, deserialized if possible

    attr_reader :meta           # Metadata describing the message itself
                                # http://rubybunny.info/articles/exchanges.html#message_metadata

    attr_reader :delivery       # Details about the delivery of the message
                                # http://rubybunny.info/articles/queues.html#accessing_message_delivery_information

    class << self
        # Generate a random 20-digit hex string
        def create_id
            rand(2**80).to_s(16).rjust(20, '0')
        end

        # Convert the given message type name into a class. This is the inverse of #type_name.
        #
        # There must either be a top-level constant that matches the name exactly,
        # or one that is equal to the name with "Message" appended to the end.
        # The constant must also be a subclass of the class this method is called
        # on (usually BaseMessage).
        #
        # TODO: This would be a tad insecure if we ever opened up the API to untrusted
        # clients, because they could force any top-level class to autoload.
        # We could easily come up with some extra constraints to make it safe.
        def class_for_type(type)
            return self if type.nil?

            type = type.to_s

            cls = begin
                type.constantize
            rescue NameError => ex
                begin
                    "#{type}Message".constantize
                rescue NameError
                    raise ex # Re-raise the original error
                end
            end

            unless cls < self
                raise TypeError, "Message type #{cls} does not descend from #{self}"
            end

            cls
        end

        # Get the type name of this message class. This is the inverse of #class_for_type.
        #
        # The type name is simply the name of the class, unless that name ends in "Message",
        # in which case that part is chopped off.
        def type_name
            @type_name ||= default_type_name(self)
        end

        def default_type_name(cls)
            unless cls.parent_name.nil?
                raise TypeError, "Message type #{cls} is not a top-level constant"
            end
            cls.name.sub(/Message\z/, '')
        end

        def inherited(subclass)
            super
            subclass.type_name
        end

        # Return a new message wrapping the given parameters (in Bunny format). If a
        # type is given, and message subclass exists matching the type, the returned
        # object will be an instance of that class. Otherwise, a BaseMessage instance
        # is returned.
        def deserialize(delivery, meta, payload)
            meta.type or raise TypeError, "Message has no type: #{meta.inspect}"
            msg = class_for_type(meta.type).allocate
            msg.before_init
            msg.deserialize(delivery, meta, payload)
            msg.after_init
            msg
        end

        def new(*args)
            msg = allocate
            msg.before_init
            msg.send(:initialize, *args)
            msg.after_init
            msg
        end

        def fields
            @fields ||= {}
        end

        def field(name, **options)
            name = name.to_sym
            fields[name] = options

            define_method name do
                self.payload[name]
            end

            define_method "#{name}=" do |value|
                self.payload[name] = value
            end
        end

        def headers
            @headers ||= {}
        end

        def header(name, **options)
            headers[name.to_sym] = options
            name = name.to_s

            define_method name do
                self.meta.headers[name]
            end

            define_method "#{name}=" do |value|
                self.meta.headers[name] = value
            end
        end
    end

    header :protocol_version
    header :document_id

    def protocol_version
        meta.headers['protocol_version'].to_i
    end

    def protocol_version=(version)
        meta.headers['protocol_version'] = version.to_i
    end

    # Called for both deserialized and manually created messages,
    # before the respective initialization method is called.
    def before_init
    end

    # Called for both deserialized and manually created messages,
    # after the respective initialization method is called.
    def after_init
    end

    # Called instead of +initialize+, when deserializing a message
    # received via AMQP.
    def deserialize(delivery, meta, payload)
        @meta = Meta.build(**meta)
        @delivery = Delivery.build(**delivery)

        # Bunny gives seconds in a String
        @meta.expiration = @meta.expiration.to_i.seconds if @meta.expiration.is_a? String

        # Deserialize the payload if it's JSON
        payload = JSON.parse(payload) if payload.is_a?(String) && json?
        @payload = payload.symbolize_keys
    end

    # Called only for manually created messages. Deserialized messages
    # call +deserialize+ instead. If you want to run initial code for
    # both cases, override +before_init+ or +after_init+.
    def initialize(payload: {}, headers: {}, in_reply_to: nil, **opts)
        @meta = Meta.build(**opts)
        @delivery = Delivery.build(**opts)

        # A few simple defaults
        @meta.message_id ||= self.class.create_id
        @meta.app_id ||= APP_ID
        @meta.type ||= self.class.type_name
        @meta.content_type ||= 'application/json'

        @meta.headers = {
            protocol_version: ApiModel.protocol_version
        }.merge(headers.symbolize_keys)

        if in_reply_to
            @meta.correlation_id = in_reply_to.meta.message_id
            @delivery.routing_key = in_reply_to.meta.reply_to if in_reply_to.meta.reply_to
        end

        @payload = payload.symbolize_keys

        self
    end

    def [](field)
        payload[field.to_sym]
    end

    # True if the message content-type is 'application/json'
    def json?
        meta.content_type == 'application/json'
    end

    # Serialize the payload based on the content-type. If the type is not handled,
    # return the payload unchanged.
    def serialize
        if json?
            payload.to_json
        else
            payload
        end
    end

    # Compile the metadata and delivery info stored in this message to a Hash of options
    # that can be passed to Bunny::Exchange.publish
    def publish_options
        opts = {}
        meta.members.each{|k| opts[k] = meta[k] }
        delivery.members.each{|k| opts[k] = delivery[k] }

        # Bunny expects milliseconds
        opts[:expiration] = opts[:expiration].in_milliseconds if opts[:expiration]

        opts
    end

    def needs_reply?
        meta.reply_to
    end

    def is_reply?
        meta.correlation_id
    end

    def valid_reply_to?(req)
        !req.meta.reply_to.nil? && req.meta.reply_to == delivery.routing_key && req.meta.message_id == meta.correlation_id
    end

    def timestamp
        Time.at(meta.timestamp) if meta.timestamp
    end

    def timestamp=(time)
        meta.timestamp = time.to_i
    end

    def to_s
        "<#{self.class}: meta=#{self.meta} delivery=#{self.delivery} payload=#{self.payload}>"
    end

    alias_method :inspect, :to_s
end
