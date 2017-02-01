require_relative 'assertions'

module MongoidAssertions
    include Assertions

    # Assert that some documents exist matching the given Mongoid::Criteria
    def assert_exists(criteria, msg=nil)
        criteria.exists? or flunk_generic("Expected some #{criteria.klass} to exist where #{criteria.selector}, but none exist", msg)
    end

    def refute_exists(criteria, msg=nil)
        criteria.exists? and flunk_generic("Expected no #{criteria.klass} to exist where #{criteria.selector}, but some do exist", msg)
    end

    # Assert that a document matching the given criteria was created within the given block
    def assert_created(criteria, msg=nil)
        criteria = criteria.all
        before = criteria.count
        yield
        created = criteria.count - before
        created == 1 or flunk_generic("Expected one #{criteria.klass} to be created where #{criteria.selector}, but #{created} were created")
    end

    def refute_created(criteria, msg=nil)
        criteria = criteria.all
        before = criteria.count
        yield
        created = criteria.count - before
        created <= 0 or flunk_generic("Expected no #{criteria.klass} to be created where #{criteria.selector}, but #{created} were created")
    end

    def assert_count(exp_count, criteria, msg=nil)
        criteria = criteria.all
        act_count = criteria.count
        unless act_count == exp_count
            cond = " where #{criteria.selector}" unless criteria.selector.empty?
            flunk_generic("Expected #{exp_count} #{criteria.klass} to exist#{cond}, but #{act_count} exist", msg)
        end
    end

    # Assert that exactly one document exists matching the given Mongoid::Criteria
    def assert_one(criteria, msg=nil)
        criteria = criteria.all
        unless criteria.one?
            msg = [msg, "Expected one #{criteria.klass} to exist where #{criteria.selector}"].compact.join("\n")
            if criteria.many?
                flunk "#{msg}, but #{criteria.count} exist:\n#{criteria.to_a.join(' ')}"
            else
                flunk "#{msg}, but none exist"
            end
        end
        criteria.one # Return the document
    end

    def assert_none(criteria, msg=nil)
        criteria.exists? and flunk [msg, "Expected no #{criteria.klass} to exist where #{criteria.selector}, but #{criteria.count} exist"].compact.join("\n")
    end

    def assert_valid(doc, field=nil)
        if field.nil?
            doc.invalid? and flunk "Document failed validation"
        elsif doc.invalid? && !doc.errors[field].empty?
            flunk "Field #{field}=#{doc[field].inspect} fails validation: #{doc.errors[field]}"
        end
    end

    def refute_valid(doc, field=nil)
        if field.nil?
            doc.valid? and flunk "Expected document to fail validation, but it passed"
        elsif doc.valid? || doc.errors[field].empty?
            flunk "Expected field #{field}=#{doc[field].inspect} to fail validation, but it passed"
        end
    end

    def assert_saved_field(field, doc)
        unless raw = doc.class.collection.find(_id: doc.id).first
            flunk "Expected document #{doc.id} to be saved the database, but it was not found"
        end
        unless raw.key?(field.to_s)
            flunk "Expected field #{field} to be saved in the database, but it was not found in the document"
        end
    end

    def refute_saved_field(field, doc)
        unless raw = doc.class.collection.find(_id: doc.id).first
            flunk "Expected document #{doc.id} to be saved the database, but it was not found"
        end
        if raw.key?(field.to_s)
            flunk "Expected field #{field} to not be saved in the database, but it was found in the document"
        end
    end
end

module MongoidTestHelpers
    def new_model(name: nil, &block)
        name ||= new_constant_name("Model")
        u = name.to_s.underscore

        new_class(name: name) do
            include Mongoid::Document
            store_in database: u, collection: u

            instance_exec(&block) if block
        end
    end
end
