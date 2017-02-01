class User
    # Git integration, used to link users on the revisions page.
    # There is currently no UI to edit this, it must be set in the console.
    module Git
        extend ActiveSupport::Concern

        included do
            [:github, :gitlab].each do |provider|
                name = :"#{provider}_verified"
                field name, type: String
                unset_if_blank name
                attr_accessible name, as: :user
                index({name => 1}, {unique: true, sparse: true})
            end
        end # included do
    end # Github
end
