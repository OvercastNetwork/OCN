require 'test_helper'

class UserHelperTest < ActiveSupport::TestCase
    include UserHelper

    def refute_normalized(url)
        assert_equal url, normalize_user_urls(url)
    end

    test "normalize short profile link" do
        user = create(:user)
        assert_equal "https://#{ORG::DOMAIN}/#{user.uuid}",
                     normalize_user_urls("https://#{ORG::DOMAIN}/#{user.username}")
    end

    test "normalize long profile link" do
        user = create(:user)
        assert_equal "https://#{ORG::DOMAIN}/#{user.uuid}",
                     normalize_user_urls("https://#{ORG::DOMAIN}/users/#{user.username}")
    end

    test "normalize avatar link" do
        user = create(:user)
        assert_equal "https://avatar.#{ORG::DOMAIN}/#{user.uuid}/32@2x.png",
                     normalize_user_urls("https://avatar.#{ORG::DOMAIN}/#{user.username}/32@2x.png")
    end

    test "normalize user tag" do
        user = create(:user)
        assert_equal "[user:#{user.uuid}]", normalize_user_urls("[user:#{user.username}]")
        assert_equal "[avatar:#{user.uuid}]", normalize_user_urls("[avatar:#{user.username}]")
        assert_equal "[avatar_user:#{user.uuid}]", normalize_user_urls("[avatar_user:#{user.username}]")
    end

    test "normalize profile link with surrounding text" do
        user = create(:user)
        assert_equal "click here: https://#{ORG::DOMAIN}/#{user.uuid} right now",
                     normalize_user_urls("click here: https://#{ORG::DOMAIN}/#{user.username} right now")
    end

    test "normalize profile link with prior username" do
        user = create(:user, username: "OldName")
        user.claim_username!("NewName")
        user.reload

        assert_equal "https://#{ORG::DOMAIN}/#{user.uuid}",
                     normalize_user_urls("https://#{ORG::DOMAIN}/OldName")
    end

    test "don't normalize profile link with unknown username" do
        url = "https://#{ORG::DOMAIN}/Nobody"
        refute_normalized url
    end

    test "don't normalize profile link with ambiguous username" do
        create(:user, username: "SharedName").claim_username!("NewName1")
        create(:user, username: "SharedName").claim_username!("NewName2")

        url = "https://#{ORG::DOMAIN}/SharedName"
        refute_normalized url
    end

    test "don't normalize reserved paths" do
        refute_normalized "https://#{ORG::DOMAIN}/play"
        refute_normalized "https://#{ORG::DOMAIN}/forums"
    end
end
