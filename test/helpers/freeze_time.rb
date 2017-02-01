# Wraps all tests in a Timecop.freeze block
module FreezeTime
    extend ActiveSupport::Concern

    included do
        around_test do |_, block|
            begin
                Timecop.freeze
                block.call
            ensure
                Timecop.return
            end
        end
    end
end
