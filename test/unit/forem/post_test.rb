require 'test_helper'

class PostTest < ActiveSupport::TestCase
    test "user links normalized on save" do
        topic = create(:topic)
        user = topic.user
        post = topic.posts.build
        post.user = user
        post.text = "Look at my profile --> https://#{ORG::DOMAIN}/#{user.username} it's awesome"
        post.save!

        assert_equal "Look at my profile --> https://#{ORG::DOMAIN}/#{user.uuid} it's awesome",
                     post.reload.text
    end
end
