# Mixin to make a model "soft deletable". This provides a framework for making
# instances of the model effectively deleted, aka "dead", while keeping them
# in the database so that references to them on other models are not made invalid.
#
# Deletable models have a timestamp field named #died_at that is normally nil.
# Instances with a died_at value should be treated as effectively non-existant
# in whatever ways possible.
#
# The default_scope is automatically set to #alive, which means that dead instances
# are excluded from queries by default. The #unscoped method can be used to get a
# query without this clause, and the #dead scope can be used to query only
# dead instances.

module Killable
    extend ActiveSupport::Concern
    include Mongoid::Document

    class Indestructible < Exception
        def initialize(model, message: nil)
            super(message || "#{model} is soft-deletable and cannot be destroyed")
        end
    end

    DESTROY_OVERRIDE = ThreadLocal.new

    class << self
        def with_destroy_override(&block)
            DESTROY_OVERRIDE.with(true, &block)
        end
    end

    included do
        field :died_at, type: Time, default: nil

        scope :dead, ne(died_at: nil)
        scope :alive, where(died_at: nil)

        default_scope -> { alive }

        define_callbacks :death, :revival

        around_save do |_, save_block|
            dead_before, dead_after = changes['died_at']

            if !dead_before && dead_after
                run_callbacks :death do
                    save_block.call
                end
            elsif dead_before && !dead_after
                run_callbacks :revival do
                    save_block.call
                end
            else
                save_block.call
            end
        end

        before_destroy do
            raise Indestructible.new(self.class) unless DESTROY_OVERRIDE.get
            true
        end

        # TODO: Maybe some magic to deal with indexes
    end

    module ClassMethods
        def die!(at: nil)
            all.each_with_validation do |doc|
                doc.die!(at: at)
            end
        end

        def revive!
            all.each_with_validation(&:revive!)
        end
    end

    def alive?
        died_at.nil?
    end

    def dead?
        !alive?
    end

    def mark_dead(at: nil)
        self.died_at = at || Time.now.utc
    end

    def mark_alive
        self.died_at = nil
    end

    def die(at: nil)
        mark_dead(at: at)
        save
    end

    def die!(at: nil)
        mark_dead(at: at)
        save!
    end

    def revive
        mark_alive
        save
    end

    def revive!
        mark_alive
        save!
    end
end
