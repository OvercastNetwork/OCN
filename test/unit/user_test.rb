require 'test_helper'

class UserTest < ActiveSupport::TestCase
    TEST_UUID = "00000000-0000-4000-8000-000000000000" # v4 UUID
    TEST_IP = "123.45.67.89"
    OTHER_IP = "123.54.76.98"

    test "username normalized on save" do
        names = ["myname", "MYNAME", "MyName", " myname "]

        names.each do |name|
            user = User.create!(uuid: TEST_UUID, username: name, player_id: name).reload
            assert_equal "myname", user.username_lower
            user.delete

            user = User.create!(uuid: TEST_UUID, username: "realname", player_id: "realname", nickname: name)
            assert_equal "myname", user.nickname_lower
            user.delete
        end
    end

    test "invalid username format fails validation" do
        user = create(:user)
        names = ["", " ", "badchar!", "white space", "toooooooooooolong"]

        names.each do |name|
            user.username = name
            refute_valid user, :username

            user.nickname = name
            refute_valid user, :nickname
        end
    end

    test "create duplicate username fails" do
        user = create(:user)
        assert_raises Mongo::Error::OperationFailure do
            User.create!(uuid: TEST_UUID, username: user.username, player_id: "something")
        end
    end

    test "uuid normalized on save" do
        user = User.create!(username: "Woot", uuid: "01234567-89AB-4DEF-8123-456789ABCDEF", player_id: "Woot")
        assert_equal "0123456789ab4def8123456789abcdef", user.uuid
    end

    test "invalid uuid format fails validation" do
        uuids = ["", "woot", " 0123456789ab4def8123456789abcdef", "123456789ab4def8123456789abcdef"]

        uuids.each do |uuid|
            user = create(:user)
            user.uuid = uuid
            refute_valid user, :uuid
        end
    end

    test "create duplicate uuid fails" do
        user = create(:user)
        assert_raises Mongo::Error::OperationFailure do
            User.create!(username: "bob", player_id: "bob", uuid: user.uuid)
        end
    end

    def assert_just_logged_in(user, ip)
        assert_equal ip, user.mc_last_sign_in_ip
        assert_member user.mc_ips, ip
        assert_now user.mc_last_sign_in_at
    end

    test "login existing player" do
        existing = create(:user, mc_sign_in_count: 1)

        Timecop.freeze do
            user = User.login(existing.uuid, existing.username, TEST_IP).reload

            assert_equal existing, user
            assert_equal existing.uuid, user.uuid
            assert_equal existing.player_id, user.player_id
            assert_equal existing.username, user.username
            assert_now user.username_verified_at

            assert_just_logged_in user, TEST_IP
            assert_equal 2, user.mc_sign_in_count
        end
    end

    test "login new player" do
        Timecop.freeze do
            user = User.login(TEST_UUID, "Alice", TEST_IP).reload

            assert_exists user.where_self

            assert_equal User.normalize_uuid(TEST_UUID), user.uuid
            assert_equal "_#{user.id}", user.player_id

            assert_equal "Alice", user.username
            assert_equal "alice", user.username_lower
            assert_now user.username_verified_at

            assert_size 1, user.usernames
            assert_equal "Alice", user.usernames[0].exact
            assert_equal "alice", user.usernames[0].canonical

            assert_just_logged_in user, TEST_IP
            assert_equal 1, user.mc_sign_in_count
            assert_now user.mc_first_sign_in_at
        end
    end

    test "offline login existing player" do
        existing = create(:user, mc_last_sign_in_ip: TEST_IP)
        user = User.login(nil, existing.username, TEST_IP)
        assert_equal existing, user
    end

    test "offline login new player raises" do
        assert_raises User::Login::Errors::OfflineUserNotFound do
            User.login(nil, "Alice", TEST_IP)
        end
    end

    test "offline login wrong username raises" do
        create(:user, mc_last_sign_in_ip: TEST_IP)
        assert_raises User::Login::Errors::OfflineUserNotFound do
            User.login(nil, "Wrong", TEST_IP)
        end
    end

    test "offline login wrong IP raises" do
        user = create(:user, mc_last_sign_in_ip: TEST_IP)
        assert_raises User::Login::Errors::OfflineUserNotFound do
            User.login(nil, user.username, OTHER_IP)
        end
    end

    test "login existing user with changed name" do
        existing = create(:user, username: "OldName")
        User.login(existing.uuid, "NewName", TEST_IP)
        assert_equal "NewName", existing.reload.username
    end

    def stub_reverse(uuid: nil)
        Mojang.stubs(:username_to_uuid).returns(uuid || TEST_UUID)
    end

    def stub_forward(uuid: nil, name: nil)
        Mojang::Profile.stubs(:from_uuid)
            .returns(Mojang::Profile.new('id' => uuid || TEST_UUID,
                                         'name' => name || "TestName",
                                         'properties' => []))
    end

    def stub_profile(uuid: nil, name: nil)
        stub_forward(uuid: uuid, name: name)
        stub_reverse(uuid: uuid)
    end

    test "login existing user with conflicting changed name" do
        # An existing user changes their name from "OldName" to "NewName".
        # Another user changes their name from "NewName" to "OtherName".
        # The first user logs in.

        existing = create(:user, username: "OldName")
        conflict = create(:user, username: "NewName")
        stub_profile(uuid: conflict.uuid, name: "OtherName")

        User.login(existing.uuid, "NewName", TEST_IP)

        assert_equal "NewName", existing.reload.username
        assert_equal "OtherName", conflict.reload.username
    end

    test "create new user with conflicting name" do
        # An existing user changes their name from "OldName" to "NewName".
        # A new user logs in as "OldName".

        conflict = create(:user, username: "OldName")
        stub_profile(uuid: conflict.uuid, name: "NewName")

        new_user = User.login(TEST_UUID, "OldName", TEST_IP)

        assert_equal "NewName", conflict.reload.username
        assert_equal "OldName", new_user.reload.username
    end

    test "two users swap names" do
        # Two users swap usernames and then one of them logs in.
        user1, user2 = create_list(:user, 2)
        name1 = user1.username
        name2 = user2.username
        stub_profile(uuid: user2.uuid, name: name1)

        User.login(user1.uuid, name2, TEST_IP)

        assert_equal name2, user1.reload.username
        assert_equal name1, user2.reload.username
    end

    test "user replaces account and keeps old name" do
        # An existing user has their old account deactivated (by Mojang)
        # and then logs in with a new account that has the same name.
        old_user = create(:user)
        name = old_user.username
        stub_forward(uuid: old_user.uuid, name: name)
        stub_reverse(uuid: TEST_UUID)

        new_user = User.login(TEST_UUID, name, TEST_IP)

        assert_equal name, new_user.reload.username
        assert_equal old_user.fallback_username, old_user.reload.username
    end

    test "new user logs in with someone else's username" do
        # A new user logs in with the name of an existing user.
        # This should never happen.
        existing = create(:user)
        stub_profile(uuid: existing.uuid, name: existing.username)

        assert_raises User::Identity::UsernameError do
            User.login(TEST_UUID, existing.username, TEST_IP)
        end
    end

    test "claim register token" do
        user = create(:unregistered_user)
        token = User.generate_register_token
        user.claim_register_token(token)

        assert_equal token, user.reload.register_token
    end

    test "claim register token when already confirmed raises" do
        user = create(:user)
        token = User.generate_register_token

        assert_raises User::RegisterError do
            user.claim_register_token(token)
        end
    end

    test "claim invalid register token raises" do
        user = create(:unregistered_user)
        [nil, '', '0123456789a-', '0123456789abc'].each do |token|
            assert_raises User::RegisterError do
                user.claim_register_token(token)
            end
        end
    end

    test "claim already claimed register token raises" do
        token = User.generate_register_token
        create(:unregistered_user, register_token: token)
        user = create(:unregistered_user)

        assert_raises User::RegisterError do
            user.claim_register_token(token)
        end
    end
end
