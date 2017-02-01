module MongoSetupAndTeardown
    extend ActiveSupport::Concern

    included do
        around_test do |_, block|
            Cache::RequestManager.unit_of_work(&block)
        end
    end

    delegate :unit_of_work, to: Cache::RequestManager

    def verify_no_data
        Mongoid::Config.models.each do |model|
            if model.database_name
                model.unscoped.count > 10 and raise "Refusing to run tests because test database contains #{model.count} documents for model #{model}:\n#{model.all.to_a.inspect}"
            end
        end
    end

    def purge_data
        User.count > 100 and raise "Refusing to purge test database because it has over 100 users"

        # Purge all data in the test database
        Mongoid::Config.models.each do |model|
            if model.database_name
                model.mongo_client.collections.each do |collection|
                    collection.find.delete_many
                end
            end
        end
    end

    def create_indexes
        unless $mongo_indexes_created
            Mongoid::Config.models.each do |model|
                model.remove_indexes
                model.create_indexes
            end
            $mongo_indexes_created = true
        end
    end

    def before_setup
        purge_data
        create_indexes
        super
    end

    def after_teardown
        purge_data
        super
    end
end

module MongoTestDatabase
    def create_test_database
        puts "Creating test database"
        @test_mongo_dir = Dir.mktmpdir('test')
        @test_mongo_port = (Mongoid::Config.sessions['default']['hosts'][0].split(':')[1] || 27017).to_i
        command = Shellwords.join(['mongod', '--port', @test_mongo_port, '--dbpath', @test_mongo_dir])
        @test_mongo_pid = Process.spawn(command, in: '/dev/null', out: '/dev/null')[2]
        @test_mongo_pid or raise "Failed to create test database"
    end

    def destroy_test_database
        if @test_mongo_pid
            puts "Destroying test database"
            Process.kill 'HUP', @test_mongo_pid
            Process.waitpid @test_mongo_pid
            FileUtils.remove_dir @test_mongo_dir
        end
    end
end

# TODO: make this work
# MiniTest::Unit.runner.extend MongoTestDatabase
