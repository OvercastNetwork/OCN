# TODO: Don't recreate the database for every test
module CouchSetupAndTeardown
    def before_setup
        db = CouchPotato.couchrest_database
        puts "Creating CouchDB test database '#{db.name}'"

        unless db.create!
            puts "WARNING: CouchDB test database '#{db.name}' already exists"
            count = db.all_docs['total_rows']
            count < 10 or raise "Refusing to run tests because CouchDB test database is not empty (#{count} documents)"
            db.recreate!
        end

        @test_database_name = db.name
        super
    end

    def after_teardown
        db = CouchPotato.couchrest_database
        if @test_database_name && @test_database_name == db.name
            puts "Deleting CouchDB test database '#{db.name}'"
            @test_database_name = nil
            db.delete!
        end
        super
    end
end
