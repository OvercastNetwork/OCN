module ActiveSupport
    module JSON
        class << self
            # Monkey patch for allow_nan: true
            def decode(json, options = {})
                if options.present?
                    raise ArgumentError, "In Rails 4.1, ActiveSupport::JSON.decode no longer " +
                    "accepts an options hash for MultiJSON. MultiJSON reached its end of life " +
                    "and has been removed."
                end

                data = ::JSON.parse(json, quirks_mode: true, allow_nan: true)

                if ActiveSupport.parse_json_times
                    convert_dates_from(data)
                else
                    data
                end
            end
        end
    end
end
