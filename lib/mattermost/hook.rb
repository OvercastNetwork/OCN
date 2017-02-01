module Mattermost
    class Hook
        HOST = '...'
        PORT = 443

        class << self
            def start(&block)
                Net::HTTP.start(HOST, PORT, use_ssl: true, &block)
            end
        end

        def initialize(id)
            @id = id
        end

        def request(json = nil)
            req = Net::HTTP::Post.new("/hooks/#{@id}")
            req['Content-Type'] = 'application/json'
            req.body = json.to_json if json
            req
        end


        def post(post, sync: true)
            if sync
                Hook.start do |http|
                    http.request request(post)
                end
            else
                Thread.new do
                    Raven.capture do
                        post(post, sync: true)
                    end
                end
            end
        end
    end
end
