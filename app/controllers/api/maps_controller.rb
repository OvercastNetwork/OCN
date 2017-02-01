module Api
    class MapsController < ModelController
        controller_for Map

        def rate
            mr = Couch::MapRating.new player_id: player_param.player_id,
                                      map_id: model_instance.id,
                                      map_version: Map.parse_version(optional_param(:map_version)),
                                      score: int_param(:score),
                                      comment: optional_param(:comment)
            mr.save!(conflict: :ours)
            respond
        end

        def get_ratings
            version = Map.parse_version(required_param(:map_version))
            player_ids = array_param(:player_ids)
            ratings = Couch::MapRating.for_map_users(model_instance, version, player_ids).mash{|mr| [mr.player_id, mr.score] }
            respond player_ratings: ratings
        end

        def update_multi
            uuids = params[:documents].to_a.flat_map{|map| [*map[:author_uuids], *map[:contributor_uuids]] }.uniq

            users_by_uuid = User.in(uuid: uuids).index_by(&:uuid)
            player_ids_by_uuid = {}

            reply = do_update_multi do |map|
                map.author_ids = []
                map.author_uuids.to_a.each do |uuid|
                    if user = users_by_uuid[uuid]
                        map.author_ids << user.id
                        player_ids_by_uuid[uuid] = user.api_player_id
                    end
                end
                map.contributor_uuids.to_a.each do |uuid|
                    if user = users_by_uuid[uuid]
                        player_ids_by_uuid[uuid] = user.api_player_id
                    end
                end
            end

            reply.users_by_uuid = users_by_uuid.mash do |uuid, user|
                [uuid, user.api_document(only: [:_id, :player_id, :username, :uuid, :nickname, :minecraft_flair])]
            end

            respond_with_message reply
        end

        protected

        def create_update_multi_response
            MapUpdateMultiResponse.new
        end
    end
end
