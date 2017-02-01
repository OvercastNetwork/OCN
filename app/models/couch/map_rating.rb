module Couch
    class MapRating
        include CouchPotato::Persistence
        include CouchHelper

        property :player_id,               type: String
        property :map_id,                  type: String
        property :map_version,             type: Array
        property :score,                   type: Fixnum
        property :comment,                 type: String

        validates_presence_of :player_id, :map_id, :score
        validates :map_version, 'Map::Version' => true
        validates_numericality_of :score
        validates_inclusion_of :score, in: (1..5)

        derived_property :id do
            self.class.make_id(map_id, map_version, player_id) unless map_id.blank? || player_id.blank?
        end

        def initialize(user: nil, **attrs)
            super(**attrs)
            self.user = user if user
        end

        def user
            @user ||= User.by_player_id(self.player_id) if self.player_id
        end

        def user=(user)
            @user = user
            self.player_id = user && user.player_id
        end

        class << self
            def make_id(map, version, user)
                map = map.id if map.is_a? Map
                version = Map.parse_version(version)
                user = user.player_id if user.is_a? User

                "MapRating:#{map}:#{version.to_a.join('.')}:#{user}"
            end
        end

        class AggregateScoreView < CouchPotato::View::BaseViewSpec
            def view_path
                "#{design_document}/#{view_name}"
            end

            def get_changes(**opts)
                CouchPotato.couchrest_database.changes(filter: '_view', view: view_path, **opts)
            end

            def reduce_function
                <<-JS
                function(keys, values, rereduce) {
                    var weight = 0;
                    var score = 0;
                    var dist = [0, 0, 0, 0, 0];

                    for(var i = 0; i < values.length; i++) {
                        var value = values[i];

                        weight += value[0];
                        score += value[1];

                        dist[0] += value[2][0];
                        dist[1] += value[2][1];
                        dist[2] += value[2][2];
                        dist[3] += value[2][3];
                        dist[4] += value[2][4];
                    }

                    return [weight, score, dist];
                }
                JS

                # TODO: get this working some day if we want a big speed boost
                # <<-ERL
                #     fun(Keys, Values, ReReduce) ->
                #         lists:foldl(fun({Weight, Score, {D1, D2, D3, D4, D5}}, {SumWeight, SumScore, {S1, S2, S3, S4, S5}}) ->
                #             {SumWeight + Weight,
                #              SumScore + Score,
                #              {S1 + D1, S2 + D2, S3 + D3, S4 + D4, S5 + D5}}
                #         end, {0,0,{0,0,0,0,0}}, Values)
                #     end.
                # ERL
            end
        end

        class ScoreByMapView < AggregateScoreView
            def map_function
                <<-JS
                function(doc) {
                    if(doc.ruby_class === "Couch::MapRating") {
                        var dist = [0, 0, 0, 0, 0];
                        dist[doc.score - 1] = 1;
                        emit([doc.map_id, doc.map_version[0], doc.map_version[1]], [1, doc.score, dist]);
                        emit([doc.map_id, null, null], [1, doc.score, dist]);
                    }
                }
                JS

                # TODO: get this working some day if we want a big speed boost
                # <<-ERL
                #     fun({Doc}) ->
                #         MapId = couch_util:get_value(<<"map_id">>, Doc),
                #         [Major, Minor] = couch_util:get_value(<<"map_version">>, Doc),
                #         Score = couch_util:get_value(<<"score">>, Doc),
                #         Dist = case Score of
                #             1 -> {1,0,0,0,0};
                #             2 -> {0,1,0,0,0};
                #             3 -> {0,0,1,0,0};
                #             4 -> {0,0,0,1,0};
                #             5 -> {0,0,0,0,1}
                #         end,
                #         Emit({MapId, Major, Minor}, {1, Score, Dist})
                #     end.
                # ERL
            end
        end

        class ScoreByDateView < AggregateScoreView
            def map_function
                <<-JS
                function(doc) {
                    if(doc.ruby_class === "Couch::MapRating") {
                        var dist = [0, 0, 0, 0, 0];
                        dist[doc.score - 1] = 1;
                        emit([doc.updated_at, doc.map_id, doc.map_version[0], doc.map_version[1]], [1, doc.score, dist]);
                        emit([doc.updated_at, doc.map_id, null], [1, doc.score, dist]);
                    }
                }
                JS
            end
        end

        view :score_by_map, type: ScoreByMapView
        view :score_by_date, type: ScoreByDateView
        view :by_map_user, key: [:map_id, :map_version, :player_id]

        class << self
            def current_version_key(map)
                [map.id, *map.version[0..1]]
            end

            def all_versions_key(map)
                [map.id, nil, nil]
            end

            def ratings_from_row(value)
                if value
                    Map::Ratings.new(value.mash(:count, :total, :dist))
                else
                    Map::Ratings.new
                end
            end

            # Get the AggregateScores for both the current version and all versions of all the given maps
            def aggregate_scores(*maps, **opts)
                keys = maps.flat_map do |map|
                    [[map.id, *map.version[0..1]], [map.id, nil, nil]]
                end

                CouchPotato.database.view(score_by_map(group: true, keys: keys, **opts))['rows'].mash{|row| [row['key'], row['value']] }
            end

            def update_maps!(*maps)
                keys = maps.flat_map do |map|
                    [current_version_key(map), all_versions_key(map)]
                end

                rows = CouchPotato.database.view(score_by_map(group: true, keys: keys))['rows'].mash{|row| [row['key'], row['value']] }

                maps.each do |map|
                    map.current_ratings = ratings_from_row(rows[current_version_key(map)])
                    map.lifetime_ratings = ratings_from_row(rows[all_versions_key(map)])
                    map.save!
                end
            end

            # Get the individual MapRating for the given map and version for
            # a list of users. A list of MapRatings is returned, in the
            # respective order, with nils for users who have not rated.
            def for_map_users(map, version, users)
                map = map.id if map.is_a? Map
                version = Map.parse_version(version)
                keys = users.map do |user|
                    make_id(map, version, if user.is_a?(User) then user.player_id else user end)
                end

                CouchPotato.database.load(keys)
            end
        end
    end
end
