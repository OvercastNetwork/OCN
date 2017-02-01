module Origin
    module Selectable
        # Return a clone of the Selectable that selects everything
        def base_selectable(selector = {})
            s = clone
            s.selector = selector
            s
        end

        # Return a selectable with the selector of self wrapped
        # in an $and operation, which ensures that filters further down
        # the chain cannot expand the selection.
        def isolate_selection
            if selector.empty? || selector.keys == [$and]
                self
            else
                base_selectable($and => [selector])
            end
        end

        # Return the intersection of this Selectable with another
        def &(s)
            base_selectable.all_of(selector, s.selector)
        end

        # Return the union of this Selectable with another
        def |(s)
            base_selectable.any_of(selector, s.selector)
        end

        # Return a selection that will not match anything.
        # This is a lame way to implement it, but Origin
        # doesn't provide a proper implementation.
        def none
            all_of(id: nil)
        end

        def upsert(doc)
            doc = doc.as_document
            doc.delete('_id')

            collection.find(selector).update(doc, [:upsert])

            self
        end

        # This is overridden in Document to actually process the keys based on the model fields
        # See Mongoid::Document#cooked_selector
        def cooked_selector(raw)
            raw
        end

        # Generate alternative query methods (ending with !) that
        # verify the existence of all symbols in the query, and
        # properly handle relations with a custom primary_key,
        # i.e. if the related object is referenced by a field other
        # than _id, the value of that field will be extracted from
        # the instance passed in.
        [:where, :ne, :in, :nin, :lt, :lte, :gt, :gte].each do |name|
            define_method "#{name}!" do |criteria|
                send(name, cooked_selector(criteria))
            end
        end
    end
end

# This copies the methods in Selectable to Findable, which is how
# they become class methods of Document. Since we just added some
# methods, we have to do this again to copy them over.
Mongoid::Findable.select_with :with_default_scope
