# encoding: utf-8
module Mongoid
    module Errors
        class Validations < MongoidError
            # Monkey patch to include document _id in validation error message
            def initialize(document)
                @document = document

                super(
                    compose_message(
                        "validations",
                        {
                            document: "#{document.class}{_id=#{document.id.inspect}}",
                            errors: document.errors.full_messages.join(", ")
                        }
                    )
                )
            end
        end

        class MultiValidations < MongoidError
            attr_reader :documents, :errors, :messages

            def initialize(documents)
                @documents = documents

                @errors = Hash.default{ Set[] }
                @messages = Set[]
                @documents.each do |doc|
                    doc.errors.keys.each do |attr|
                        @errors[attr] += doc.errors[attr]
                    end
                    @messages += doc.errors.full_messages
                end
            end
        end
    end
end
