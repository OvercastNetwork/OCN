class Inquiry
    include Mongoid::Document

    field :username
    field :email
    field :subject
    field :message
end
