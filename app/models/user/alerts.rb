class User
    # Stuff related to alerts and subscriptions
    #
    # See also #Alert and #Subscribable
    module Alerts
        extend ActiveSupport::Concern

        included do
            has_many :subscriptions, class_name: 'Subscription'
            has_many :alerts
        end # included do
    end # Alerts
end
