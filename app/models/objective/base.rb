module Objective
    class Base
        include Mongoid::Document
        include DisablePolymorphism
        include ApiModel
        include ApiAnnounceable
        store_in :database => 'oc_objectives', :collection => 'objectives'

        field :type, type: String
        field :name, type: String
        field :feature_id, type: String
        field :player
        field :date, type: Time
        field :team, type: String

        field :x, type: Float
        field :y, type: Float
        field :z, type: Float

        belongs_to :server
        belongs_to :match
        field :family, type: String

        required = [:match_id, :server_id, :family, :type, :player, :date]
        optional = [:x, :y, :z, :feature_id, :name, :team]
        # TODO: Require name after core_name -> name migration

        attr_accessible :_id, *required, *optional
        api_property *required, *optional
        validates_presence_of *required

        scope :user, -> (user) { where(player: user.player_id).hint(INDEX_player) }

        index(INDEX_date = {date: -1})
        index(INDEX_player = {player: 1})
        index(INDEX_type = {type: 1, player: 1})
        index(INDEX_family = {family: 1})
        index(INDEX_match = {match_id: 1})

        class << self
            def class_for_type(type)
                Objective.const_get(type.to_s.camelize)
            rescue NameError
                self
            end

            def type_name
                name.split(/::/).last.underscore
            end

            def new(attrs = nil)
                if self == Base
                    instantiate(attrs)
                else
                    super
                end
            end

            def instantiate(attrs = nil, *args)
                type = attrs['type'] if attrs
                if self == Base && type && klass = class_for_type(type)
                    klass.new(attrs)
                else
                    super
                end
            end

            def queryable
                if self < Base
                    super.where(type: type_name)
                else
                    super
                end
            end

            def total_description # override me
                "#{type_name} completed"
            end

            def join_matches(objectives = all, matches: Match.all)
                objectives = objectives.to_a

                match_ids = objectives.select{|o| o.match_id && !o.relation_set?(:match) }.map(&:match_id)
                unless match_ids.empty?
                    matches_by_id = matches.in(id: match_ids.uniq).index_by(&:id)

                    objectives.each do |objective|
                        objective.set_relation(:match, matches_by_id[objective.match_id]) if objective.match_id && !objective.relation_set?(:match)
                    end
                end

                objectives
            end
        end

        def name
            self[:name]
        end

        def description
            name
        end

        def html_color
            'none'
        end

        def team_dye_color
            DyeColor.parse(self.team.downcase.gsub(' team', '')) if team
        end

        def team_html_color
            if dye = team_dye_color
                dye.to_html_color
            else
                'none'
            end
        end
    end
end
