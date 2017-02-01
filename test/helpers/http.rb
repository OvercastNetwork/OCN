module HttpTestHelpers
    def header_to_env(headers = {})
        headers.mash do |name, value|
            ["HTTP_#{name.gsub(/-/, '_').upcase}", value]
        end
    end
end
