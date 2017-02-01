module Dropbox
    class Client
        include Loggable

        BASE_URI = URI.parse("https://api.dropboxapi.com")

        def initialize(token:)
            @token = token
            @http = Net::HTTP.new(BASE_URI.host, BASE_URI.port)
            @http.use_ssl = true
            @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

            @accounts = {}
            @entries = {}
            @listings = {}
            @shared_folders = {}
        end

        def add_headers(req)
            req['Content-Type'] = 'application/json'
            req['Authorization'] = "Bearer #{@token}"
        end

        def make_post(path, body)
            req = Net::HTTP::Post.new(path)
            add_headers(req)
            req.body = body
            req
        end

        def request(req)
            res = @http.request(req)
            unless res.is_a? Net::HTTPSuccess
                raise "Dropbox API request failed: #{res.code} #{res.message}\n#{res.body}"
            end
            JSON.parse(res.body)
        end

        def post(path, json = nil)
            logger.info "Dropbox: #{path} #{json.inspect}"
            request(make_post(path, json.to_json))
        end

        def account(account_id)
            @accounts[account_id] ||= Account.new(self, post('/2/users/get_account', account_id: account_id))
        end

        def current_account
            @current_account ||= Account.new(self, post('/2/users/get_current_account'))
        end

        def entry(path = '')
            @entries[path.downcase] ||= Entry.create(self, post('/2/files/get_metadata', path: path))
        end

        def entries(path = '')
            @listings[path.downcase] ||= post('/2/files/list_folder', path: path)['entries'].map do |json|
                @entries[json['path_lower']] = Entry.create(self, json)
            end
        end

        def shared_folder(shared_folder_id)
            @shared_folders[shared_folder_id] ||= SharedFolder.new(self, post('/2/sharing/get_folder_metadata', shared_folder_id: shared_folder_id))
        end

        def shared_folders
            @shared_folders = post('/2/sharing/list_folders')['entries'].map{|json| SharedFolder.new(self, json) }.index_by(&:shared_folder_id)
        end
    end
end
