require 'test_helper'

class RelationMacrosTest < ActiveSupport::TestCase
    test "referenced relations not validated by default" do
        [:belongs_to, :has_one, :has_many, :has_and_belongs_to_many].each do |macro|
            model = new_model do
                __send__ macro, :related
            end

            refute model.relations['related'].validate?,
                "#{macro} relations should not be validated by default"
        end
    end

    test "embedded relations validated by default" do
        [:embeds_one, :embeds_many].each do |macro|
            model = new_model do
                __send__ macro, :related
            end

            assert model.relations['related'].validate?,
                   "#{macro} relations should be validated by default"
        end
    end

    test "validate option" do
        [:belongs_to, :has_one, :has_many, :has_and_belongs_to_many].each do |macro|
            model = new_model do
                __send__ macro, :related, validate: true
            end

            assert model.relations['related'].validate?,
                   "#{macro} relations should support the :validate option"
        end
    end
end
