
FAMILY = Family.find('practice')
UNUSED_FAMILY = Family.find('practice-unused')

dry_run = !ARGV.delete('--commit')
all_teams = ARGV.delete('--all')

puts "Dry run, no changes will be made (use --commit to save changes)" if dry_run

unless tournament_name = ARGV[0] and boxes = ARGV[1]
    puts "Usage:\npractice_servers.rb <tournament name> <boxes>"
    exit(1)
end

boxes = boxes.split(',')

tournament = Tournament.or({name: tournament_name}, {url: tournament_name}).first or raise "No tournament named #{tournament_name}"

teams = if all_teams
    Team.in_tournament(tournament).to_a
else
    tournament.accepted_team_ids.map do |team_id|
        Team.find(team_id) or raise "Bad team #{team_id}"
    end
end

teams.sort_by!(&:name)
servers = Set.new
ordinal = 1

teams.each_with_index do |team, index|
    server = Server.find_or_create_by(bungee_name: "#{ordinal}-practice")

    server.tournament = tournament
    server.team = team
    server.name = team.name
    server.priority = index

    server.family_obj = FAMILY
    server.role = Server::Role::PGM
    server.network = Server::Network::TOURNAMENT
    server.datacenter = 'TM'
    server.settings_profile = 'tournament'

    server.box = boxes[index % boxes.size]
    server.ip = "#{server.box_id}.lan"
    server.port = 0

    server.realms = ['global', 'practice', 'untourney']
    server.visibility = Server::Visibility::PUBLIC
    server.whitelist_enabled = true

    puts "#{server.name} assigned to #{server.bungee_name} on #{server.box}"
    if dry_run
        raise "Server failed validation" unless server.valid?
    else
        server.save!
    end

    servers << server
    ordinal += 1
end

extra = Server.family(FAMILY).nin(id: servers.map(&:id)).by_priority
if extra.exists?
    puts "Removing extra servers: #{extra.map(&:bungee_name).join(' ')}"

    extra.each_with_index do |server|
        server.family_obj = UNUSED_FAMILY
        server.tournament = nil
        server.team = nil
        server.name = "Unused #{ordinal}"
        server.visibility = Server::Visibility::UNLISTED
        server.whitelist_enabled = true

        if dry_run
            raise "Server failed validation" unless server.valid?
        else
            server.save!
        end

        ordinal += 1
    end
end
