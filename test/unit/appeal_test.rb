require 'test_helper'

class AppealTest < ActiveSupport::TestCase

    test "creates action" do
        user = create(:user)
        appeal = build(:appeal, punished: user)
        appeal.save!

        assert_exists appeal.actions
    end

    test "add excuses" do
        punished = create(:user)
        kick = create(:kick, punished: punished)
        ban = create(:ban, punished: punished)

        appeal = Appeal.new(punished: punished)
        appeal.add_excuse(kick, "Kick Excuse")
        appeal.add_excuse(ban, "Ban Excuse")
        appeal.save!

        appeal.reload

        assert_equal kick, appeal.excuses[0].punishment
        assert_equal kick.punisher, appeal.excuses[0].punisher, "should copy punisher into appeal"
        assert_equal ban, appeal.excuses[1].punishment
        assert_equal ban.punisher, appeal.excuses[1].punisher, "should copy punisher into appeal"
    end

    test "subscribes punished user" do
        user = create(:user)
        user.confirm!
        create(:group, permissions: ['appeal.view.own'], members: [user])

        appeal = build(:appeal, punished: user)
        appeal.save!

        assert_exists appeal.subscriptions.where(user: appeal.punished)
    end
end
