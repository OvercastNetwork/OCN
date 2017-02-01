module Mongoid
    module Relations
        module Accessors
            # Test if the given relation has been loaded
            def relation_set?(name)
                self.class.metadata(name)
                instance_variable_defined? "@_#{name}"
            end

            def set_relation_with_check(name, value)
                self.class.metadata(name)
                set_relation_without_check(name, value)
            end
            alias_method_chain :set_relation, :check

            module ClassMethods
                def relation_changes(*names)
                    names.each do |name|
                        meta = metadata(name)
                        key = meta.key
                        model = meta.klass

                        alias_method :"#{name}_changed?", :"#{key}_changed?"

                        define_method "#{name}_was" do
                            if __send__("#{key}_changed?")
                                model.find(__send__("#{key}_was"))
                            else
                                __send__(name)
                            end
                        end

                        define_method "#{name}_was?" do
                            !__send__("#{name}_was").nil?
                        end

                        define_method "#{name}_change" do
                            if __send__("#{key}_changed?")
                                [model.find(send("#{key}_was")), send(name)]
                            end
                        end
                    end
                end
            end
        end
    end
end
