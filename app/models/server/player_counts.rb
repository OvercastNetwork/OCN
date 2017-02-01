class Server
    module PlayerCounts
        extend ActiveSupport::Concern
        include Lifecycle

        included do
            field :min_players,         type: Integer, default: 0
            field :max_players,         type: Integer, default: 0

            field :num_online,          type: Integer, default: 0
            field :num_participating,   type: Integer, default: 0
            field :num_observing,       type: Integer, default: 0

            scope :non_empty, -> { gt(num_online: 0) }

            counts = [:min_players, :max_players, :num_online, :num_participating, :num_observing]
            attr_accessible *counts
            api_property *counts
            validates_numericality_of *counts

            before_event :up_or_down do
                self.num_online = 0
                self.num_participating = 0
                self.num_observing = 0
                true
            end

            before_validation do
                self.num_participating = num_participating.to_i
                self.num_observing = num_observing.to_i
                self.num_online = num_participating + num_observing
                true
            end
        end # included do
    end # PlayerCounts
end
