require_relative 'script_helpers'

# Hyphenates User UUIDs

puts "Scanning for convertible UUIDs (will take about #{User.count / 7000.0} seconds)..."

User.where(uuid: /[0-9a-f]{32}/).each_print_progress do |user|
    user.set(uuid: User.normalize_uuid(user.uuid))
end
