require 'test_helper'

class PunishmentTest < ActiveSupport::TestCase

    def add_playing_time(user, duration)
        stats = user.stats
        stats.set(:playing_time, stats.stat(:playing_time) + duration * 1000)
        stats.save!
    end

    test "user generally not banned" do
        user = create(:user)

        refute Punishment.banned?(user)
        assert_nil Punishment.current_ban(user)
    end

    test "permanent ban" do
        user = create(:user)
        create(:ban, punished: user)

        assert Punishment.banned?(user)
        assert_nil Punishment.current_ban(user).expire
    end

    test "ban the right user" do
        guilty = create(:user)
        innocent = create(:user)
        create(:ban, punished: guilty)

        assert Punishment.banned?(guilty)
        refute Punishment.banned?(innocent)
    end

    test "punish sequence" do
        guilty = create(:user)
        create(:kick, punished: guilty)

        assert_equal [Punishment::Type::BAN, 7.days], Punishment.calculate_next_game(guilty)

        create(:ban, punished: guilty)

        assert_equal [Punishment::Type::BAN, nil], Punishment.calculate_next_game(guilty)
    end

    test "forum punish sequence" do
        guilty = create(:user)

        assert_equal [Punishment::Type::FORUM_WARN, nil], Punishment.calculate_next_forum(guilty)

        create(:forum_warn, punished: guilty)

        assert_equal [Punishment::Type::FORUM_WARN, nil], Punishment.calculate_next_forum(guilty)

        create(:forum_warn, punished: guilty)

        assert_equal [Punishment::Type::FORUM_BAN, 7.days], Punishment.calculate_next_forum(guilty)

        create(:forum_ban, punished: guilty)

        assert_equal [Punishment::Type::FORUM_BAN, 30.days], Punishment.calculate_next_forum(guilty)

        create(:forum_ban, punished: guilty)

        assert_equal [Punishment::Type::FORUM_BAN, nil], Punishment.calculate_next_forum(guilty)
    end

    test "punish sequence stale" do
        Timecop.freeze do
            guilty = create(:user)

            create(:kick, punished: guilty)

            assert_equal [Punishment::Type::BAN, 7.days], Punishment.calculate_next_game(guilty)

            Timecop.freeze Punishment::STALE_REAL_TIME + 1.day do
                add_playing_time guilty, ( Punishment::STALE_PLAY_TIME + 1.second )
                assert_equal [Punishment::Type::KICK, nil], Punishment.calculate_next_game(guilty)
            end
        end
    end

    test "forum punish sequence stale" do
        Timecop.freeze do
            guilty = create(:user)

            create(:forum_warn, punished: guilty)
            create(:forum_warn, punished: guilty)

            assert_equal [Punishment::Type::FORUM_BAN, 7.days], Punishment.calculate_next_forum(guilty)

            Timecop.freeze Punishment::FORUM_STALE_TIME + 1.day do
                assert_equal [Punishment::Type::FORUM_WARN, nil], Punishment.calculate_next_forum(guilty)
            end
        end
    end

    test "temporary ban" do
        Timecop.freeze do
            user = create(:user)
            create(:ban, punished: user, expire: 2.days.from_now)

            Timecop.freeze 1.day.from_now do
                assert Punishment.banned?(user)
            end

            Timecop.freeze 3.days.from_now do
                refute Punishment.banned?(user)
            end
        end
    end

    test "inactive ban" do
        user = create(:user)
        create(:ban, punished: user, active: false)

        refute Punishment.banned?(user)
    end

    test "forum ban" do
        user = create(:user)
        create(:forum_ban, punished: user)

        assert Punishment.forum_banned?(user)
    end

    test "warning is never stale" do
        warn = create(:warn)
        Timecop.freeze 100.years.from_now do
            refute warn.stale?
        end
    end

    test "permanent ban is never stale" do
        ban = create(:ban)
        Timecop.freeze 100.years.from_now do
            refute ban.stale?
        end
    end

    test "permanent forum ban is never stale" do
        ban = create(:forum_ban)
        Timecop.freeze 100.years.from_now do
            refute ban.stale?
        end
    end

    test "kick is stale only after play time and real time" do
        Timecop.freeze do
            user = create(:user)
            kick = create(:kick, punished: user)
            refute kick.stale?

            add_playing_time user, Punishment::STALE_PLAY_TIME - 1.minute

            Timecop.freeze kick.date + Punishment::STALE_REAL_TIME - 1.minute do
                refute kick.stale?
            end
            Timecop.freeze kick.date + Punishment::STALE_REAL_TIME + 1.minute do
                refute kick.stale?
            end

            add_playing_time user, 2.minutes

            Timecop.freeze kick.date + Punishment::STALE_REAL_TIME - 1.minute do
                refute kick.stale?
            end
            Timecop.freeze kick.date + Punishment::STALE_REAL_TIME + 1.minute do
                assert kick.stale?
            end
        end
    end

    test "ban is stale relative to expire time" do
        Timecop.freeze do
            user = create(:user)
            ban = create(:ban, punished: user, expire: 2.days.from_now)

            add_playing_time user, Punishment::STALE_PLAY_TIME + 1.minute

            Timecop.freeze ban.date + Punishment::STALE_REAL_TIME + 1.day do
                refute ban.stale?
            end

            Timecop.freeze ban.date + Punishment::STALE_REAL_TIME + 3.days do
                assert ban.stale?
            end
        end
    end
end
