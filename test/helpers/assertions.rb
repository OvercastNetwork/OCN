module Assertions
    def flunk_generic(generic, msg=nil)
        flunk [msg, generic].compact.join("\n")
    end

    # Assert that an enumerable contains only the given set of elements, in any order
    def assert_set(exp, act, msg="Sets are not equal")
        exp = Set.new(exp)
        act = Set.new(act)

        if exp != act
            missing = exp - act
            extra = act - exp

            msg = "#{msg}\nMissing: #{missing.to_a.join(' ')}" unless missing.empty?
            msg = "#{msg}\nExtra: #{extra.to_a.join(' ')}" unless extra.empty?

            flunk msg
        end
    end

    # Assert that an enumerable contains the given sequence of elements, in the correct order
    def assert_sequence(exp, act, msg="Sequences are not equal")
        exp = [*exp]
        act = [*act]

        if exp != act
            flunk "#{msg}\nExpected: #{exp.join(' ')}\nActual: #{act.join(' ')}"
        end
    end

    def normalize_time(time)
        time = time.utc
        Time.utc time.year, time.month, time.day, time.hour, time.min, time.sec
    end

    # Assert the equality of two Times, correcting for inaccuracy introduced by the database
    def assert_same_time(exp, act, msg=nil)
        assert_equal normalize_time(exp), normalize_time(act), msg
    end

    def assert_now(time, msg=nil)
        assert_same_time Time.now, time, msg
    end

    def assert_never(time, msg=nil)
        assert_equal Time::INF_FUTURE, time, msg
    end

    def refute_earlier(exp, act, msg=nil)
        act < exp and flunk_generic("Expected #{act} not to be earlier than #{exp}", msg)
    end

    def assert_member(seq, mem, msg=nil)
        seq.member?(mem) or flunk_generic("Expected #{mem} to be in the sequence", msg)
    end

    def refute_member(seq, mem, msg=nil)
        seq.member?(mem) and flunk_generic("Expected #{mem} not to be in the sequence", msg)
    end

    def assert_size(size, seq, msg=nil)
        seq.size == size or flunk_generic("Expected #{size} elements, but there were #{seq.size}", msg)
    end

    def email_fields_equal(exp, act)
        if act.is_a?(Enumerable) and !exp.is_a?(Enumerable)
            act.any?{|x| email_fields_equal(exp, x) }
        elsif exp.is_a?(Regexp)
            act.to_s =~ exp
        elsif exp.is_a?(String)
            act.to_s == exp
        else
            act == exp
        end
    end

    def assert_email_sent(params={})
        emails = ActionMailer::Base.deliveries
        emails.empty? and flunk "No emails were sent"

        emails.each do |message|
            return if params.all? do |field, exp|
                email_fields_equal(exp, message.send(field))
            end
        end

        if emails.size == 1
            flunk "An email was sent, but it did not match\nExpected: #{params.inspect}\nActual: #{emails.first.inspect}\n#{emails.first.body}"
        else
            flunk "#{emails.size} emails were sent, but none of them matched\nExpected: #{params.inspect}"
        end
    end
end
