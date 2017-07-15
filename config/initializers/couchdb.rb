host = ENV['COUCH_HOST'] || 'localhost'
port = 5984
database = 'ocn'

CouchPotato::Config.database_host = "http://#{host}:#{port}"
CouchPotato::Config.database_name = database

# Minimize view rebuilds when code is updated
CouchPotato::Config.split_design_documents_per_view = true

CouchPotato.couchrest_database.create! # does nothing if DB already exists
