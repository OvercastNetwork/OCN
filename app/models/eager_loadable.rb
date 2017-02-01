module EagerLoadable
    extend ActiveSupport::Concern
    include Mongoid::Document
    include InheritedAttributes
    
    included do
        mattr_inherited_list :imap_keys

        after_save do
            self.class.imap.clear
        end
    end # included do

    module ClassMethods
        def index_in_memory(*attrs)
            attrs.each{|attr| imap_keys << attr }
        end

        # Load all documents into the identity map
        def imap
            im = super
            unless im.key?({})
                # Make sure to put {} in the map before calling
                # eager_load on the docs, or stack overflow.
                docs = im[{}] = unscoped.all.to_a
                docs.each(&:eager_load)
            end
            im
        end

        def loaded
            imap[{}]
        end
    end # ClassMethods

    def eager_load
        store_in_imap
        self.class.imap_keys.each do |key|
            store_in_imap(key)
        end
    end
end
