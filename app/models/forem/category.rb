module Forem
    class Category
        include Mongoid::Document
        include Mongoid::Timestamps
        store_in :database => "oc_forem_categories"

        field :name
        field :order, :type => Integer, :default => 0

        has_many :forums, :class_name => 'Forem::Forum'
        validates :name, :presence => true
        attr_accessible :name, :order

        class << self
            def by_order
                asc(:order)
            end
        end

        def to_s
            name
        end

        def can_view?(user = nil)
            visible = false
            self.forums.each do |forum|
                visible = true if forum.can_view?(user)
            end
            visible
        end
    end
end
