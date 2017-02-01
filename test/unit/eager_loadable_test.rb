require 'test_helper'

class EagerLoadableTest < ActiveSupport::TestCase
    test "all instances loaded to identity map on first access" do
        model = new_model do
            include EagerLoadable
        end
        5.times{ model.create! }

        clear_request_cache

        assert_size 5, model.imap_all
        model.imap_all.each do |doc|
            assert model.imap_find(doc.id)
        end
    end

    test "secondary keys eager loaded to identity map" do
        model = new_model do
            include EagerLoadable
            field :name
            index_in_memory :name
        end
        model.create!(name: 'woot')

        clear_request_cache

        assert model.imap_where(name: 'woot')
    end

    test "identity map is purged when any document is modified" do
        model = new_model do
            include EagerLoadable
            field :name
        end
        old_docs = 5.times.map{ model.create! }

        clear_request_cache

        doc = model.imap_all[0]
        doc.name = 'woot'
        doc.save!

        old_docs.each do |old_doc|
            refute_same old_doc, model.imap_find(old_doc.id)
        end
    end

    test "belongs_to relations load from identity map" do
        related = new_model do
            include EagerLoadable
        end
        model = new_model do
            belongs_to :related, class_name: related.name, inverse_of: nil
        end

        doc = model.create!(related: related.create!)

        clear_request_cache

        assert_same related.imap_all[0], doc.reload.related
    end
end
