require 'test_helper'

class ViewableTest < ActiveSupport::TestCase
    class Thing
        include Mongoid::Document
        include Viewable
    end

    test "never updated" do
        Timecop.freeze do
            thing = Thing.create!
            refute thing.visibly_updated_since? 1.minute.ago
        end
    end

    test "mark updated" do
        Timecop.freeze do
            thing = Thing.create!
            thing.mark_visibly_updated!
            thing.reload
            t1 = Time.now

            refute thing.visibly_updated_since? t1

            Timecop.freeze(1.minute)
            thing.mark_visibly_updated!
            thing.reload
            t2 = Time.now

            assert thing.visibly_updated_since? t1
            refute thing.visibly_updated_since? t2

            Timecop.freeze(1.minute)
            thing.mark_visibly_updated!
            thing.reload
            t3 = Time.now

            assert thing.visibly_updated_since? t1
            assert thing.visibly_updated_since? t2
            refute thing.visibly_updated_since? t3
        end
    end

    test "unviewed" do
        user = create(:user)
        thing = Thing.create!

        refute thing.viewed_by? user
        refute thing.visibly_updated_for? user
        assert_nil thing.unread_count_for(user)
    end

    test "initial view" do
        Timecop.freeze do
            user = create(:user)
            thing = Thing.create!
            thing.register_view_by!(user)

            assert thing.viewed_by? user
            refute thing.visibly_updated_for? user
            assert_equal 0, thing.unread_count_for(user)
        end
    end

    test "update after view" do
        Timecop.freeze do
            user = create(:user)
            thing = Thing.create!
            thing.register_view_by!(user)

            Timecop.freeze(1.minute)

            thing.reload.mark_visibly_updated!
            thing.reload

            assert thing.visibly_updated_for? user
            assert_equal 1, thing.unread_count_for(user)
        end
    end

    test "repeat view after update" do
        Timecop.freeze do
            user = create(:user)
            thing = Thing.create!
            thing.register_view_by!(user)

            Timecop.freeze(1.minute)

            thing.mark_visibly_updated!
            thing.reload
            thing.register_view_by!(user)
            thing.reload

            refute thing.visibly_updated_for? user
            assert_equal 0, thing.unread_count_for(user)
        end
    end
end
