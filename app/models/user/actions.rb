class User
    # Stuff related to actions
    #
    # See also #Action::Base and #Actionable
    module Actions
        extend ActiveSupport::Concern

        included do
            has_many :actions, class_name: 'Action::Base'
        end # included do
    end # Actions
end
