require 'test_helper'

class CustomAtomicOperationsTest < ActiveSupport::TestCase
    test "atomic min" do
        doc = new_model do
            field :woot
        end.create(woot: 1)

        doc.atomic_min(woot: 2)
        assert_equal 1, doc.woot
        assert_equal 1, doc.reload.woot

        doc.atomic_min(woot: 0)
        assert_equal 0, doc.woot
        assert_equal 0, doc.reload.woot
    end

    test "atomic max" do
        doc = new_model do
            field :woot
        end.create(woot: 1)

        doc.atomic_max(woot: 0)
        assert_equal 1, doc.woot
        assert_equal 1, doc.reload.woot

        doc.atomic_max(woot: 2)
        assert_equal 2, doc.woot
        assert_equal 2, doc.reload.woot
    end

    test "atomically block" do
        model = new_model do
            field :a
            field :b
        end
        doc = model.create(a: 1, b: 1)

        doc.atomically do
            # Operations should not persist until the block returns
            doc.atomic_min(a: 0)
            doc.atomic_max(b: 2)

            assert_equal 1, model.find(doc.id).a
            assert_equal 1, model.find(doc.id).b
        end

        assert_equal 0, model.find(doc.id).a
        assert_equal 2, model.find(doc.id).b
    end
end
