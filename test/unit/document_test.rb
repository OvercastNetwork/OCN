require 'test_helper'

class DocumentTest < ActiveSupport::TestCase
    class DoubleInner
        include Mongoid::Document
        field :value
        attr_accessible :_id, :value
    end

    class Inner
        include Mongoid::Document
        field :value
        belongs_to :double_inner, class_name: 'DocumentTest::DoubleInner'
        attr_accessible :_id, :value, :double_inner
        accepts_nested_attributes_for :double_inner
    end

    class Outer
        include Mongoid::Document
        belongs_to :inner, class_name: 'DocumentTest::Inner'
        attr_accessible :inner
        accepts_nested_attributes_for :inner
    end

    test "replace nil relation with new document" do
        outer = Outer.create!
        outer.update_relation!(:inner, {value: 123})
        outer.save!

        assert_one Inner
        assert_equal Inner.first, Outer.first.inner
    end

    test "replace nil relation with existing document" do
        inner = Inner.create!
        outer = Outer.create!
        outer.update_relation!(:inner, {_id: inner.id})
        outer.save!

        assert_one Inner
        assert_equal Inner.first, Outer.first.inner
    end

    test "update document through relation" do
        Outer.create!(inner: Inner.create!(value: 123))

        outer = Outer.first
        outer.update_relation!(:inner, {value: 456})
        outer.save!

        assert_one Inner
        assert_equal 456, Inner.first.value
    end

    test "replace related document with new document" do
        Outer.create!(inner: Inner.create!(value: 123))

        inner_id = BSON::ObjectId.new
        outer = Outer.first
        outer.update_relation!(:inner, {_id: inner_id, value: 456})
        outer.save!

        assert_count 2, Inner
        assert_one Inner.where(value: 123)
        assert_one Inner.where(_id: inner_id, value: 456)
        assert_equal 456, Outer.first.inner.value
    end

    test "replace related document with existing document" do
        Outer.create!(inner: Inner.create!(value: 123))

        inner = Inner.create!(value: 456)
        outer = Outer.first
        outer.update_relation!(:inner, {_id: inner.id, value: 789})
        outer.save!

        assert_count 2, Inner
        assert_one Inner.where(value: 123)
        assert_one Inner.where(value: 789)
        assert_equal 789, Outer.first.inner.value
    end

    test "nested mass assignment" do
        outer = Outer.create!
        attrs = {inner: {value: 123}}
        outer.update_relations!(attrs)
        outer.save!

        assert_one Inner.where(value: 123)
        assert_equal 123, Outer.first.inner.value
    end

    test "second order nesting" do
        outer = Outer.create!
        outer.update_relations!(inner: {value: 123, double_inner: {value: 456}})
        outer.save!

        assert_one Inner.where(value: 123)
        assert_one DoubleInner.where(value: 456)
        assert_equal 123, Outer.first.inner.value
        assert_equal 456, Outer.first.inner.double_inner.value
    end

    test "relation_set? macro" do
        inner = Inner.create!
        outer = Outer.create!(inner: inner)
        assert outer.relation_set?(:inner)

        outer = Outer.find(outer.id)
        refute outer.relation_set?(:inner)

        outer.inner
        assert outer.relation_set?(:inner)

        outer = Outer.find(outer.id)
        outer.set_relation(:inner, inner)
        assert outer.relation_set?(:inner)
    end

    test "relation names checked" do
        outer = Outer.new

        assert_raises TypeError do
            outer.relation_set?(:woot)
        end

        assert_raises TypeError do
            outer.set_relation(:woot, nil)
        end
    end
end
