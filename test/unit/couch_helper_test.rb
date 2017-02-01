require 'test_helper'

class CouchHelperTest < ActiveSupport::TestCase
    include CouchSetupAndTeardown

    class TestModel
        include CouchPotato::Persistence
        include CouchHelper

        property :woot
        validates_presence_of :woot
    end

    test "validation fails" do
        refute TestModel.new.save
    end

    test "validation raises" do
        assert_raises CouchPotato::Database::ValidationsFailedError do
            TestModel.new.save!
        end
    end

    test "save conflict raises" do
        doc = TestModel.new
        doc.woot = 'initial'
        doc.save!
        base_rev = doc._rev
        refute_nil base_rev

        doc.woot = 'theirs'
        doc.save!
        their_rev = doc._rev
        refute_equal base_rev, their_rev

        doc.woot = 'ours'
        doc._rev = base_rev
        assert_raises CouchPotato::Conflict do
            doc.save!
        end
    end

    test "automatic conflict resolution" do
        doc = TestModel.new
        doc.woot = 'initial'
        doc.save!
        base_rev = doc._rev

        doc.woot = 'theirs'
        doc.save!
        their_rev = doc._rev

        doc.woot = 'ours'
        doc._rev = base_rev
        doc.save!(conflict: :ours)
        doc.reload
        assert_equal 'ours', doc.woot
        refute_nil doc._rev
        refute_equal base_rev, doc._rev
        refute_equal their_rev, doc._rev
    end
end
