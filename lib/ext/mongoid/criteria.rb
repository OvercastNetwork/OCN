module Mongoid
    class Criteria
        def cooked_selector(raw)
            klass.cooked_selector(raw)
        end

        def prefetch(*fields)
            if fields.empty?
                self
            else
                if cached?
                    pf = Prefetcher.new(self)
                    fields.each do |field|
                        pf.add_field(field)
                    end
                    pf.fetch
                    self
                else
                    cache.prefetch(*fields)
                end
            end
        end

        def each_with_validation
            failed = []

            result = each do |doc|
                begin
                    yield doc
                rescue Mongoid::Errors::Validations
                    failed << doc
                end
            end

            unless failed.empty?
                raise Mongoid::Errors::MultiValidations.new(failed)
            end

            result
        end

        def in_imap
            klass.imap[selector]
        end

        # Make this work with mass-assignment security
        def first_or_initialize(attrs = nil, &block)
            unless obj = first
                obj = klass.without_attr_protection{ super(&block) }
                obj.assign_attributes(attrs) if attrs
            end
            obj
        end

        # Match the given fields being an empty string, nil, or not existing at all
        def blank(*attrs)
            q = self
            attrs.each do |attr|
                q = q.or({attr => ''}, {attr => nil})
            end
            q
        end

        # Match the given fields being anything besides nil or the empty string
        def present(*attrs)
            q = self
            attrs.each do |attr|
                q = q.nin(attr => [nil, ''])
            end
            q
        end

        # If there is one and only one result, return it, otherwise return nil
        def one_or_nil
            e = each
            doc = e.next
            e.next
            nil
        rescue StopIteration
            doc
        end

        def include?(doc)
            where(id: doc.id).exists?
        end
    end
end
