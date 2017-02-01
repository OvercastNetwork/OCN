class Dog
    def self.client
        @client ||= Dogapi::Client.new('...')
    end
end
