require 'test_helper'

module Api
    class DeathsControllerTest < ActionController::TestCase
        include ModelControllerTest
        tests DeathsController

        # This is not specific to the Death model, but we don't have a more general place to test it
        test "update id mismatch" do
            death = build(:death)
            post :update, id: BSON::ObjectId.new, format: :json, document: death.api_document
            assert_response 400
        end
    end
end
