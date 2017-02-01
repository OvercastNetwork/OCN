require 'test_helper'

class ValidationTest < ActiveSupport::TestCase
    def assert_validates(model, attr, klass, **options)
        unless klass.is_a?(Class)
            klass = model.resolve_validator_class(klass)
        end

        attr = attr.to_s
        validators = model.validators.select{|v| v.is_a?(klass) && v.attributes.map(&:to_s).include?(attr) }

        if validators.empty?
            actual_validators = model.validators.map(&:inspect)
            flunk "Expected #{model}##{attr} to have a #{klass}, but it only had #{actual_validators}"
        end

        unless validators.any?{|v| v.options.slice(*options.keys) == options }
            actual_options = validators.map{|v| v.options.inspect }.join(', ')
            flunk "Expected #{model}##{attr} to have a #{klass} with options #{options.inspect}, but it had #{actual_options}"
        end
    end

    test "non-nil field validation" do
        model = new_model do
            field :f, allow_nil: false
        end

        assert_validates model, :f, :not_nil

        thing = model.new
        refute_valid thing, :f

        thing.f = 'woot'
        assert_valid thing, :f

        thing.f = ''
        assert_valid thing, :f
    end

    test "non-nil relation validation" do
        related = new_model

        model = new_model do
            belongs_to :r, class_name: related.name, allow_nil: false, inverse_of: nil
        end

        assert_validates model, :r, :not_nil

        thing = model.new
        refute_valid thing, :r

        thing.r = related.new
        assert_valid thing, :r
    end

    test "reference (foreign key) validation" do
        related = new_model

        model = new_model do
            belongs_to :r, class_name: related.name, inverse_of: nil, reference: true, allow_nil: true
        end

        assert_validates model, :r, :reference

        thing = model.new
        assert_valid thing, :r

        thing.r = related.create
        assert_valid thing, :r

        thing = model.new
        thing.r_id = BSON::ObjectId.new
        refute_valid thing, :r
    end

    test "implicit enum validation" do
        enum = new_class(extends: Enum) do
            create :WOOT
        end

        model = new_model do
            field :e, type: enum
        end

        thing = model.new
        refute_valid thing, :e

        thing.e = enum::WOOT
        assert_valid thing, :e

        thing = model.new(e: "lol")
        assert_raises Enum::Error do
            thing.e
        end
    end

    test "nullable enum validation" do
        enum = new_class(extends: Enum) do
            create :WOOT
        end

        model = new_model do
            field :e, type: enum, allow_nil: true
        end

        thing = model.new
        assert_valid thing, :e

        thing.e = enum::WOOT
        assert_valid thing, :e

        thing = model.new(e: "lol")
        assert_raises Enum::Error do
            thing.e
        end
    end

    test "path validation single array element" do
        doc = new_model do
            field :woot, default: -> { ['hi'] }
            validates 'woot.0', presence: true
            validates 'woot.1', presence: true
        end.new

        assert_valid doc, 'woot.0'
        refute_valid doc, 'woot.1'
    end

    test "path validation complete array" do
        doc = new_model do
            field :woot, default: -> { ['hi', nil] }
            validates 'woot.*', presence: true
        end.new

        assert_valid doc, 'woot.0'
        refute_valid doc, 'woot.1'
    end

    test "path validation single hash entry" do
        doc = new_model do
            field :woot, default: -> { {a: 1} }
            validates 'woot.a', presence: true
            validates 'woot.b', presence: true
        end.new

        assert_valid doc, 'woot.a'
        refute_valid doc, 'woot.b'
    end

    test "path validation complete hash" do
        doc = new_model do
            field :woot, default: -> { {a: 1, b: nil} }
            validates 'woot.*', presence: true
        end.new

        assert_valid doc, 'woot.a'
        refute_valid doc, 'woot.b'
    end
end
