require 'test_helper'

module Forem
    class TopicsControllerTest < ActionController::TestCase
        tests Forem::TopicsController

        # TODO: We can't test any forem controllers because they are in a "mounted engine"

        # test "show topic" do
        #     topic = create(:topic)
        #     post = create(:post, topic: topic)
        #
        #     get :show, id: topic.id
        # end
    end
end
