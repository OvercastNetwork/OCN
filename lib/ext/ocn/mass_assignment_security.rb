module OCN
    module MassAssignmentSecurity
        module Macros
            extend ActiveSupport::Concern

            def in_mass_assignment_context?(context)
                if context.is_a?(Module)
                    if is_a?(Module)
                        self < context
                    else
                        is_a?(context)
                    end
                else
                    self == context
                end
            end

            def mass_assignment_option_stack
                Thread.current[:mass_assignment_options] ||= []
            end

            def mass_assignment_options
                final_opts = {}
                mass_assignment_option_stack.each do |context, opts|
                    if in_mass_assignment_context?(context)
                        final_opts.merge!(opts)
                    end
                end
                final_opts
            end

            def with_mass_assignment_options(**opts, &block)
                stack = mass_assignment_option_stack
                stack.push([opts[:context] || self, opts])
                begin
                    block.call
                ensure
                    stack.pop
                end
            end

            def with_attr_protection(**opts, &block)
                with_mass_assignment_options(without_protection: false, **opts, &block)
            end

            def without_attr_protection(**opts, &block)
                with_mass_assignment_options(without_protection: true, **opts, &block)
            end

            def with_assignment_role(role, **opts, &block)
                with_mass_assignment_options(role: role, **opts, &block)
            end

            def without_assignment_role(**opts, &block)
                with_mass_assignment_options(role: nil, **opts, &block)
            end
        end

        extend Macros

        module DocumentExtensions
            extend ActiveSupport::Concern
            include ActiveModel::MassAssignmentSecurity

            # Configure mass-assignment violations to raise in development and log to Sentry in production.
            # This is missing from Mongoid's configuration, so we have to do it this way.
            # See #ActiveModel::MassAssignmentSecurity::RavenSanitizer
            included do
                self.mass_assignment_sanitizer = if ['production', 'test'].include? Rails.env
                    RavenSanitizer.new(self)
                else
                    :strict
                end
            end

            include Macros
            module ClassMethods
                include Macros
            end

            def sanitize_for_mass_assignment(attributes, role = nil)
                if mass_assignment_options[:without_protection]
                    attributes
                else
                    role ||= mass_assignment_options[:role]

                    # Don't complain about illegal attribute assignments if the value
                    # is unchanged (and don't do the assignment either).
                    attributes = attributes.reject do |k, v|
                        read_attribute(k) == v
                    end

                    # For whatever reason, Devise tries to mass-assign the email field after a failed login,
                    # and generates lots of pointless errors. This is the best solution I could think of.
                    if self.is_a?(User) && attributes.key?('email') && !caller.grep(%r[devise/sessions_controller]).empty?
                        attributes.delete('email')
                    end

                    _mass_assignment_sanitizer.sanitize(self.class, attributes, mass_assignment_authorizer(role))
                end
            end
        end

        class RavenSanitizer < ActiveModel::MassAssignmentSecurity::LoggerSanitizer
            def process_removed_attributes(klass, attrs)
                raise "Can't mass-assign protected attributes on #{klass}: #{attrs.join(' ')}"
            rescue => ex
                Raven.capture_exception(ex)
            end
        end
    end
end
