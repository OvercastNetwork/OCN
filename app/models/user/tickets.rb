class User
    module Tickets
        extend ActiveSupport::Concern

        def ticket
            Ticket.for_user(self)
        end
    end # Tickets
 end
