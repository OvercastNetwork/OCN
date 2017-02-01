require 'test_helper'

class UserPremiumTest < ActiveSupport::TestCase
    UUID = "00000000-0000-4000-8000-000000000000" # v4 UUID
    IP = "123.45.67.89"

    setup do
        @premium_group = create(:premium_group)
        @trial_group = User::Premium.trial_group
        @length = User::Premium::TRIAL_LENGTH
    end

    around_test do |_, block|
        Timecop.freeze(User::Premium::TRIAL_CUTOFF + 1.year, &block)
    end

    def assert_trial(user, remaining: nil, used: nil)
        now = Time.now
        assert user.trial_active?
        assert user.in_group?(@trial_group)

        if remaining
            assert_equal remaining, user.trial_expires_at - now
        end

        if used
            start = user.trial_started_at || now
            assert_equal used, now - start - user.used_premium_time_between(start..now)
        end
    end

    def refute_trial(user)
        refute user.trial_active?
        refute user.in_group?(@trial_group)
        assert_nil user.trial_expires_at
    end

    test "trial active on first login" do
        user = User.login(UUID, "Alice", IP)
        assert_trial user, remaining: @length
    end

    test "trial starts on first login after participating" do
        user = User.login(UUID, "Alice", IP)
        assert_nil user.trial_started_at

        Timecop.freeze(10.hours) do
            create(:participation, user: user)
            user = User.login(UUID, "Alice", IP)
            assert_trial user, remaining: @length
        end
    end

    test "trial depletes" do
        user = User.login(UUID, "Alice", IP)
        create(:participation, user: user)
        user.update_trial!

        Timecop.freeze(1.hour) do
            user.update_trial!
            assert_trial user, used: 1.hour
        end
    end

    test "trial expires" do
        user = User.login(UUID, "Alice", IP)
        create(:participation, user: user)
        user.update_trial!

        Timecop.freeze(@length + 1.hour) do
            user.update_trial!
            refute_trial user
        end
    end

    test "user who joined before cutoff is ineligible" do
        Timecop.freeze(User::Premium::TRIAL_CUTOFF - 1.hour)
        User.login(UUID, "Alice", IP)

        Timecop.freeze(2.hours)
        user = User.login(UUID, "Alice", IP)
        refute user.eligible_for_trial?
        refute_trial user
    end

    test "used premium time, permanent group" do
        user = create(:user)
        user.join_group(@premium_group, start: 3.hours.ago)

        assert_equal 3.hours, user.used_premium_time
    end

    test "used premium time, expired group" do
        user = create(:user)
        user.join_group(@premium_group, start: 3.hours.ago, stop: 1.hour.ago)

        assert_equal 2.hours, user.used_premium_time
    end

    test "used premium time, multiple groups" do
        # Use hours instead of days to avoid DST problems
        user = create(:user)
        optio, centurion, dux = create_list(:premium_group, 3)
        user.join_group(optio, start: 360.hours.ago, stop: 300.hours.ago)
        user.join_group(centurion, start: 220.hours.ago, stop: 100.hours.ago)
        user.join_group(dux, start: 7.hours.ago)

        assert_equal 187.hours, user.used_premium_time
    end

    test "trial pauses during premium membership" do
        user = User.login(UUID, "Alice", IP)

        unit_of_work do
            create(:participation, user: user)
            user.update_trial!
            assert_trial user
        end

        Timecop.freeze(1.hour)

        unit_of_work do
            user.join_group(@premium_group, stop: 1.hour.from_now)
            user.update_trial!
            refute_trial user
        end

        Timecop.freeze(2.hours)

        unit_of_work do
            user.update_trial!
            # User spent 1 hour as premium, so only 2 hours of trial should be used
            assert_trial user, used: 2.hours
        end
    end
end
