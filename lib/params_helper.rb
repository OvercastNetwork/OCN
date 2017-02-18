module ParamsHelper
    include ErrorHelper

    def raise_param_missing(key)
        raise BadRequest, "Missing required parameter '#{key}'"
    end

    def blank_to_nil_param(key)
        param = params[key]
        param = nil if param.blank?
        param
    end

    def formatted_param(key, required: false, default: nil)
        if value = blank_to_nil_param(key)
            value = yield value.to_s if block_given?
        end

        if !value.nil?
            value
        elsif default.respond_to? :call
            default.call
        elsif default
            default
        elsif required
            raise_param_missing(key)
        end
    end

    def required_param(key)
        params[key] or raise_param_missing(key)
    end

    def array_param(key)
        params[key].to_a
    end

    def optional_param(key)
        x = params[key]
        x unless x.blank?
    end

    def boolean_param(key, **opts)
        if [true, false].include? params[key]
            params[key]
        else
            formatted_param(key, **opts) do |raw|
                raw.parse_bool
            end
        end
    end

    def int_param(key, **opts)
        formatted_param(key, **opts) do |raw|
            if raw =~ /\A-?\d+\z/
                raw.to_i
            else
                raise BadRequest, "Expected parameter '#{key}' to be an integer, not: #{raw}"
            end
        end
    end

    def time_param(key, **opts)
        formatted_param(key, **opts) do |raw|
            Time.parse(raw)
        end
    end

    def choice_param(key, choices)
        unless choices.empty?
            choice = params[key]
            choice = choices[0] unless choices.include?(choice)
            choice
        end
    end

    def enum_param(enum, key = nil, **opts)
        key ||= enum.base_name.downcase
        formatted_param(key, **opts) do |raw|
            begin
                enum.deserialize(raw)
            rescue Enum::Error
                raise BadRequest.new("Bad #{enum} value '#{raw}'")
            end
        end
    end

    def model_find(criteria, key, field: :id)
        criteria.where(field => key).first or raise Mongoid::Errors::DocumentNotFound.new(criteria.all.klass, {field => key}, [key])
    end

    def model_id_param(key = :id, **opts, &block)
        formatted_param(key, **opts, &block)
    end

    def model_param(criteria, key = :id, field: :id, **opts)
        model_id_param(key, **opts) do |raw|
            model_find(criteria, raw, field: field)
        end
    end

    def model_one(criteria)
        criteria.one or raise Mongoid::Errors::DocumentNotFound.new(criteria.all.klass, criteria.selector)
    end

    def player_param(key = :player_id, **opts)
        formatted_param(key, **opts) do |raw|
            User.by_player_id(raw) or raise Mongoid::Errors::DocumentNotFound.new(User, key => raw)
        end
    end

    def username_param(key = :user, **opts)
        formatted_param(key, **opts) do |raw|
            User.by_username(raw) or raise Mongoid::Errors::DocumentNotFound.new(User, key => raw)
        end
    end
end
