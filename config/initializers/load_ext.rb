# Eager load all monkey patches (everything in lib/ext)
#
# TODO: Everything we load here is not reloadable in development,
# but we could work around that by moving things into modules
# outside of lib/ext and just put the include statements inside lib/ext
$LOAD_PATH << File.join(Rails.root, 'lib/ext')

Dir[Rails.root + 'lib/ext/**/*.rb'].each do |file|
    require file
end
