require_relative 'assertions'

module ControllerAssertions
    include Assertions

    def assert_assigns(ivar)
        assigns(ivar) or flunk "Expected ivar @#{ivar} was not assigned by the controller"
    end

    def refute_select(*args)
        elements = assert_select(*args)
        unless elements.empty?
            flunk "Expected no elements to match CSS selector #{args.last} but there was #{elements.size} match(es):\n#{elements.map(&:to_s).join("\n")}"
        end
    rescue Minitest::Assertion
        # pass
    end

    def parse_response_json
        @json_response ||= JSON.parse(@response.body)
    rescue JSON::ParserError
        flunk "Response was not valid JSON\n#{@response.body}"
    end

    def assert_json_response(exp={})
        parse_response_json
        @response.success? or flunk "Expected successful response, got #{@response.status}:\n#{@json_response.pretty_inspect}"
        exp.as_json.each do |k, v|
            @json_response[k] == v or flunk "Response field '#{k}' was not as expected\nExpected: #{exp.pretty_inspect}\nActual: #{@json_response.pretty_inspect}"
        end
        @json_response
    end

    def assert_json_collection(exp)
        assert_response :success
        act = parse_response_json
        assert act.is_a?(Hash), "Response was not a JSON object\n#{act.pretty_inspect}"

        exp.as_json.each do |field, exp_set|
            assert act.has_key?(field), "Response did not have a field named #{field}\n#{act.pretty_inspect}"
            assert exp_set.is_a?(Enumerable), "Response did not have a collection in field #{field}\n#{act.pretty_inspect}"
            assert_set exp_set, act[field]
        end
    end

    def assert_no_alerts
        if alert = flash[:alert]
            flunk "Expected no alerts, but there was an alert: #{alert}"
        end
    end
end

module ControllerTest
    extend ActiveSupport::Concern
    include ControllerAssertions

    # Rails docs lie, @request.headers does not work
    # http://stackoverflow.com/questions/9654465/how-to-set-request-headers-in-rspec-request-spec
    def request_header(headers = {})
        @request.env.merge!(header_to_env(headers))
    end
end
