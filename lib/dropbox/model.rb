module Dropbox
    class Model
        attr :client, :json

        class << self
            def field(*names)
                names = names.map(&:to_s)
                names.each do |name|
                    define_method(name) { json[name] }
                end
            end
        end

        def initialize(client, json)
            @client = client
            @json = json
        end

        def inspect
            "#<#{self.class.name} #{json.inspect}>"
        end

        def as_json(*)
            json
        end
    end
end
