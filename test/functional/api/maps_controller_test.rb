require 'test_helper'

module Api
    class MapsControllerTest < ActionController::TestCase
        include ModelControllerFindTest
        include CouchSetupAndTeardown

        tests MapsController

        test "rate map" do
            user = create(:user)
            map = create(:map)

            Timecop.freeze do
                post :rate,
                     id: map.id,
                     player_id: user.player_id,
                     map_version: map.formatted_version,
                     score: 5,
                     comment: "Comment"

                doc = CouchPotato.database.load(Couch::MapRating.make_id(map, map.version, user))
                assert doc, "MapRating should have been created"
                assert_instance_of Couch::MapRating, doc

                assert_equal user.player_id, doc.player_id
                assert_equal map.id, doc.map_id
                assert_equal map.version, doc.map_version
                assert_equal 5, doc.score
                assert_equal "Comment", doc.comment

                assert_now doc.created_at
                assert_now doc.updated_at
            end
        end
    end
end
