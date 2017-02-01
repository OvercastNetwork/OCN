# Build translations every hour and broadcast a pull message
class TranslationWorker
    include Worker

    poll delay: 1.hour do
        Translation.build!
    end
end
