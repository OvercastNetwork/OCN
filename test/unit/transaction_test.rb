require 'test_helper'

class TransactionTest < ActiveSupport::TestCase

    setup do
        @family = create(:pgm_family)
        @user = create(:user)

        @optio = create(:optio)
        @centurion = create(:centurion)
        @dux = create(:dux)
    end

    def assert_package_available(package, price: nil, time: nil)
        purchase = @purchases[package.id]
        assert purchase, "Package #{package.name} is not available at all"

        price and assert_equal price, purchase.price,
                               "Expected package #{package.name} to cost #{price} but it actually costs #{purchase.price}"

        time and assert_equal time, purchase.duration,
                              "Expected package #{package.name} to have duration #{time} but it was actually #{purchase.duration}"
    end

    def assert_package_unavailable(package)
        purchase = @purchases[package.id]
        assert purchase.nil? || purchase.price == 0,
               "Expected package #{package.name} to not be available, but it was"
    end

    def update_avails
        Cache::RequestManager.clear_request_cache
        @purchases = @user.available_purchases
    end

    test "package prices" do
        # Initially, all packages are available at full price
        update_avails
        assert_package_available @optio,     price: @optio.price
        assert_package_available @centurion, price: @centurion.price
        assert_package_available @dux,       price: @dux.price

        # User buys the cheapest package (Optio)
        create(:transaction, user: @user, package: @optio).give_package!

        # The purchased package becomes unavailable and its price is deducted from the other packages
        update_avails
        assert_package_unavailable @optio
        assert_package_available @centurion, price: @centurion.price - @optio.price
        assert_package_available @dux,       price: @dux.price - @optio.price

        # User buys the next package (Centurion) at price minus what they already payed
        create(:transaction, user: @user, package: @centurion, total: @centurion.price - @optio.price).give_package!

        # Only the last package is available
        update_avails
        assert_package_unavailable @optio
        assert_package_unavailable @centurion
        assert_package_available @dux,       price: @dux.price - @centurion.price

        # User buys the last package (Dux)
        create(:transaction, user: @user, package: @dux, total: @dux.price - @centurion.price).give_package!

        # User has now payed for the most expensive package, so nothing is left to buy
        update_avails
        assert_package_unavailable @optio
        assert_package_unavailable @centurion
        assert_package_unavailable @dux
    end

    test "package times" do
        # Initially, all packages have their full duration
        update_avails
        assert_package_available @optio,     time: @optio.time_limit
        assert_package_available @centurion, time: @centurion.time_limit
        assert_package_available @dux

        # User buys the shortest package (Optio)
        create(:transaction, user: @user, package: @optio).give_package!

        Timecop.freeze(@optio.time_limit) do
            # The first package has expires
            update_avails
            assert_package_unavailable @optio
            assert_package_available @centurion, time: @centurion.time_limit - @optio.time_limit
            assert_package_available @dux
        end

        # User buys the next package (Centurion)
        create(:transaction, user: @user, package: @centurion).give_package!

        Timecop.freeze(@centurion.time_limit) do
            # The second package expires, only the unlimited package remains
            update_avails
            assert_package_unavailable @optio
            assert_package_unavailable @centurion
            assert_package_available @dux
        end
    end

    test "give purchased package" do
        create(:transaction, user: @user, package: @optio).give_package!
        assert @user.reload.in_group?(@optio.group)
        assert_same_time @optio.time_limit.from_now, @user.membership_in(@optio.group).stop

        create(:transaction, user: @user, package: @centurion, total: @centurion.price - @optio.price).give_package!
        assert @user.reload.in_group?(@centurion.group)

        create(:transaction, user: @user, package: @dux, total: @dux.price - @centurion.price).give_package!
        assert @user.reload.in_group?(@dux.group)
    end

    test "overlapping purchases" do
        update_avails

        # Buy Optio
        create(:transaction, user: @user, package: @optio).give_package!

        Timecop.freeze(72.hours) do # specify hours to avoid DST weirdness
            update_avails
            # 3 days into Optio, Centurion should offer its limit less 3 days
            assert_package_available @centurion, time: @centurion.time_limit - 3.days
        end

        Timecop.freeze(@optio.time_limit + 3.days) do
            update_avails
            # 3 days after Optio expires, Centurion should offer its limit less Optio's limit
            assert_package_available @centurion, time: @centurion.time_limit - @optio.time_limit
        end
    end
end
