require 'test_helper'

class CustomFieldBehaviorTest < ActiveSupport::TestCase
    test "blank to nil" do
        model = new_model do
            field :woot
            attr_accessible :woot
            blank_to_nil :woot
        end

        # Blank is changed to nil on validation
        doc = model.new(woot: "")
        doc.valid?
        assert_nil doc.woot

        doc = model.new(woot: [])
        doc.valid?
        assert_nil doc.woot

        doc = model.new(woot: "something")
        doc.valid?
        assert_equal "something", doc.woot
    end

    test "unset if blank" do
        model = new_model do
            field :woot
            attr_accessible :woot
            unset_if_blank :woot
        end

        # Field can have a blank value
        doc = model.new(woot: "")
        assert_equal "", doc.woot

        # Blank value is not saved, but it is preserved
        doc.save!
        refute_saved_field(:woot, doc)
        assert_equal "", doc.woot

        # Non-blank value behaves normally
        doc.woot = "something"
        assert_equal "something", doc.woot
        doc.save!
        assert_saved_field(:woot, doc)
        assert_equal "something", doc.woot

        # Previously saved field is removed if it becomes blank again
        doc.woot = []
        doc.save!
        refute_saved_field(:woot, doc)
        assert_equal [], doc.woot
    end
end
