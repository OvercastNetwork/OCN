OCN Website/Backend
===================

This is the code that powered the website and backend services of the former Overcast/Lifeboat PC Network.

Besides the removal of some branding and configuration data, it is more or less unmodified.
It is probably not *directly* useful to third parties in its current state,
but it may be help in understanding how the [ProjectAres](https://github.com/OvercastNetwork/ProjectAres) plugins work.

We are quite open to the idea of evolving this into something more generally useful.
If you would like to contribute to this effort, talk to us in [Discord](https://discord.gg/6zGDEen).


# License

OCN Website/Backend is free software: you can redistribute it and/or modify it
under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

A copy of the GNU Affero General Public License is included in the file LICENSE.txt,
and can also be found at https://www.gnu.org/licenses/agpl-3.0.en.html

**The AGPL license is quite restrictive, please make sure you understand it.
If you run a modified version of this software as a network service,
anyone who can use that service must also have access to the modified source code.**


# Architecture

This repo contains the following components:

* Database models used by all parts of the network
* The public website, including an admin interface used for some essential configuration
* An internal HTTP API used by Bukkit and Bungee servers to interact with the model layer
* Several "worker" services that do miscellanous background tasks or respond to AMQP messages

## Install the backend app

Install the following services and configure them to run on their default
ports:
* [Ruby 2.1.5](https://www.ruby-lang.org/)
  * OS X: [RVM](http://rvm.io) is recommended over the default OS X Ruby. Here's a one-liner: `\curl -sSL https://get.rvm.io | bash -s stable --ruby
`
* [MongoDB 2.6.5](http://www.mongodb.org/)
* [Redis](http://redis.io/)
* [RabbitMQ](http://rabbitmq.com)
* [CouchDB](http://couchdb.apache.org)

Ensure bundler is installed: `gem install bundle`

Run `bundle install` to download and install dependencies.

## Setup the database

Start MongoDB, Redis, and CouchDB with default settings. Then, run the following shell commands from the Web repo:

    rake db:setup
    rake db:create_indexes

This should create several databases starting with `oc_`, generally one for each model.

The [OCN-Data](https://github.com/OvercastNetwork/OCN-Data) repo contains static configuration data for the database.
This includes things like permission groups, server families, and game types.
Clone it somewhere, and create a symlink to it from `/minecraft/repo/data`.
From the Web repo, run `rails c` to start a Rails shell session.
From the Rails shell, run `Repository[:data].load_models` to import everything from the Data repo into MongoDB.

## Run the backend app

Run the following shell commands from the Web repo to start all the backend services:

    rails octc              # Public website on http://localhost:3000
    rails api               # Internal API on http://localhost:3010
    config/worker.rb        # Worker daemon

At this point, you should be able to visit the website at `http://localhost:3000`, but there isn't much to see and you have no account to login with.
To create an account, we'll first get a Bungee and Lobby running, and then do the standard registration process.

## Create a Bungee instance

To create a Bungee server record in the database, run this in the Rails shell:

    Server.without_attr_protection{ Server.create!(
        datacenter: 'DV',
        box: Box.local_id,
        network: Server::Identity::Network::PUBLIC,
        role: Server::Role::BUNGEE,
        family: 'bungee',
        name: 'bungee-dev'
    )}

Assuming this is the first server you have created, you can retrieve it in the rails shell as `Server.first`, or `Server.bungees.first`.
Alternately, you can look it up by name (or any other field) with `Server.find_by(name: 'bungee-dev')`.
You can assign it to a local variable in the shell with `server = Server.find_by(...)`.
You can inspect fields of the server object with `server.field`.
To see the ID of the server, type `server.id.to_s`.
This 24-digit hex number is the primary key of the server in the database, and will end up in the `config.yml` file for the API plugin.

Next, setup a [BungeeCord](https://github.com/OvercastNetwork/BungeeCord) server
with the API and Commons plugins from the [ProjectAres](https://github.com/OvercastNetwork/ProjectAres) repo
(make sure to use our custom BungeeCord fork, the upstream version won't work).
In the `config.yml` file for the API plugin, fill in the top section to match the server record you just created:

    server:
      id: 0123456789abcdef01234567        # server.id.to_s
      datacenter: DV                      # server.datacenter
      box: ...                            # server.box
      role: BUNGEE

Start Bungee with a shell command similar to this:

    java -Dtc.oc.stage=DEVELOPMENT \
         -jar BungeeCord.jar

At startup, Bungee should connect to the API and retrieve its record from the database, and update that record with its current status.
If you try to connect to Bungee, you will just get an error since there is no lobby to join.

## Create a Lobby instance

Run this in the Rails shell to create a new Lobby server record:

    Server.without_attr_protection{ Server.create!(
        datacenter:'DV',
        box: Box.local_id,
        network: Server::Identity::Network::PUBLIC,
        role: Server::Role::LOBBY,
        family: 'lobby-public',
        bungee_name: 'lobby-dev',
        name: 'Lobby'
    )}

If this is the only lobby in the database, you can quickly retrieve it with `Server.lobbies.first`, or you can use any kind of`Server.find_by` query to look it up.

Setup a [SportBukkit](https://github.com/OvercastNetwork/SportBukkit) instance with the appropriate [plugins](https://github.com/OvercastNetwork/ProjectAres) for a lobby.
In the `config.yml` for the API plugin, enter the details from the lobby server record.

Start the server with a shell command similar to this:

    java -Xms1G -Xmx1G \
         -Dlog4j.configurationFile=log4j2.xml \
         -Dtc.oc.stage=DEVELOPMENT \
         -jar SportBukkit.jar

You should now be able to connect to your Bungee server and spawn in the lobby.

## Create an admin user

To create the initial admin user for the website, type this command into rails console, replacing the data fields with your account info. Make sure to replace the UUID field with the UUID of your Minecraft account, which you can find [here](https://mcuuid.net/)

		User.without_attr_protection {
				User.create!(email: 'your@email', username: 'your_username', 
				password: 'password', password_confirmation: 'password', 
				admin: true, "uuid" 'uuid').confirm!
		}


## Create a PGM instance

On the website, under Admin -> Servers, you can see all the servers you have configured, and easily create/edit them.
Use this to create a PGM server, by cloning the Lobby server and changing the role to PGM.
Then, setup the SportBukkit instance in the same way you did for the Lobby.

You now have a basic working development environment.

## Coding Conventions

✔ = *Things we presently do fairly well*

✘ = *Things we presently fail miserably at*

### Style
* ✔ We generally follow the Sun/Oracle coding standards.
* ✔ No tabs; use 4 spaces instead.
* ✔ No trailing whitespaces.
* ✔ No CRLF line endings, LF only, put your gits 'core.autocrlf' on 'true'.
* ✔ No 80 column limit or 'weird' midstatement newlines.

### Models
* ✘ The Mongoid models are the canonical schema for the database. Any applications, tools, or scripts that talk to the database should do so through these models.
* ✘ All domain logic goes in the models. Any code that is potentially useful to multiple applications should be in the model layer.
* ✘ Every collection should have a `Mongoid::Document` subclass and every field should be explicitly defined.
* ✘ Embedded documents should have their own `Mongoid::Document` subclass and use embedded relations e.g. `embeds_many`, `embedded_in`, etc.
* ✘ Foreign keys should use relations if at all possible e.g. `has_many`, `belongs_to`, etc. This should almost always be possible using custom `foreign_key` and `primary_key` options.
* ✘ Any required indexes should be declared with Mongoid's `index` method. They can then be created with `rake db:create_indexes`. This must be done manually, it is not part of deployment.
* ✘ Anything beyond trivial get/set of scalar fields should be done through methods on the model.
* ✘ Filters should be implemented as `scope`s, even if they are only expected to return a single value (this makes atomic updates simpler).
* ✘ Create/update operations should generally be class methods so they can be called at the end of chains e.g. `server.sessions.user(x).start(ip)`

### Views/Controllers
* ✘ The view layer should only be concerned with rendering the models and passing input to the models. Controller methods should do nothing beyond forwarding actions to model methods and grabbing data for the templates to use. 

### API
* ✔ Endpoints should be at the highest possible abstraction level. Any end user action should be doable with a single API call.
* ✔ Try to use the conventional CRUD resource mappings where it makes sense. Use `collection` and `member` to define routes. Actions on individual objects should have a `member` route.
* ✘ Try to use exceptions to return error responses. Let `DocumentNotFound` exceptions generate 404 responses.

### Testing
* ✘ *All* code must be checked in with tests: models, views, helpers, everything. Tests are the only weapon we have against regressions.
* ✔ Like any other code, tests must be *maintained*. As such, they should follow all the usual best practices: they should be readable, concise, modular, non-repetitive, and so on.
* ✔ One test method should test *one thing*. Avoid testing several cases at once or long sequences of operations.
* ✔ Don't be overly specific with assertions, just assert what matters. Tests should only fail if something is really broken. Example: don't assert specific error messages when all that matters is that there is an error.
* ✔ Avoid elaborate setup methods. They should only create a few things that are used by all the tests in the class.
* ✔ Tests *will* fail when changes are made. The test's job is to inform the developer how to deal with the failure quickly and conveniently.
* ✔ Use semantically specific assertions wherever possible e.g. `assert_length` instead of `assert x.size ==`, and feel free to add new ones to the test helper. The value of these is that they generate more useful failure messages.
