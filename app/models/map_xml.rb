# A map.xml file saved locally
class MapXML
    # Parses immediately and raises (what?) if this fails
    def initialize(directory)
        @directory = directory

        File.open(self.xml_path) do |f|
            @doc = Nokogiri::XML(f)
        end
    end

    def to_param
        name.strip.downcase.gsub(/\s+/,'_')
    end

    def exists?
        File.exists?(self.xml_path)
    end

    def name
        @doc.at_css("map name").inner_text
    end

    def slug
        slug = @doc.at_css("map slug")
        slug.inner_text if slug
    end

    def id
        id = @doc.at_css("map id")
        id.inner_text if id
    end

    def version
        @doc.at_css("map version").inner_text
    end

    def author_uuids
        @doc.css('map authors author').map{|a| a['uuid'] }.compact
    end

    def author_names
        @doc.css('map authors author').map{|a| a.content unless a['uuid'] }.compact
    end

    def objective
        el = @doc.at_css("map objective")
        el.inner_text if el
    end

    def genre
        el = @doc.at_css("map genre")
        el.inner_text if el
    end

    def teams
        # TODO: Support new team tag syntax
        @doc.css("map teams team").map do |team|
            {
                name: team.content,
                max_players: team.attr('max'),
                color: team.attr('color')
            }
        end
    end

    def teams_summary
        result = ""
        @doc.css("map teams team").each do |team|
            result << team.attr("max") + " " + team.content.gsub(" Team", "") + " vs "
        end
        result.chop.chop.chop.chop
    end

    def max_players
        total = 0
        @doc.css("map teams team").each do |team|
            total += team.attr("max").to_i
        end
        total
    end

    def placeholder_img
        "https://maps.#{ORG::DOMAIN}/" + self.map_folder + "map.png"
    end

    def images
        Dir.glob(File.join(self.map_path, '*.png')).map{|path| File.basename(path) }.sort
    end

    def xml_path
        self.map_path + "map.xml"
    end

    def png_path
        self.map_path + "map.png"
    end

    def folder
        File.basename(@directory)
    end

    def map_folder
        self.map_path.gsub(self.maps_path, "")
    end

    def map_path
        @directory + "/"
    end

    def pathname
        Pathname.new(@directory)
    end

    def relative_pathname
        pathname.relative_path_from(Repository[:maps].absolute_pathname)
    end

    def relative_path
        relative_pathname.to_s
    end

    def maps_path
        MapXML.maps_path
    end

    def self.root_path
        Repository::BASE_PATH
    end

    def self.maps_path
        self.root_path + "/maps/"
    end

    def self.rotations_path
        self.root_path + "/Rotations"
    end
end
