require 'uri'

class ResourcePack
    include Mongoid::Document
    store_in :database => "oc_resource_packs"

    SHA1 = OpenSSL::Digest.new('sha1')

    field :name, type: String
    field :sha1, type: String

    has_many :servers

    def self.for_branch(branch)
        find_or_create_by(name: branch)
    end

    def url
        "#{Rails.configuration.resource_pack_url_prefix}/#{URI.encode(name)}.zip"
    end

    def local_path
        "/minecraft/ResourcePack/#{name}.zip"
    end

    def update_digest
        if File.exists?(local_path)
            self.sha1 = SHA1.hexdigest(File.read(local_path))
        end
    end

    def build(**opts)
        repo = Repository[:respack]

        ShellSession.run(cd: repo.absolute_path, **opts) do |sh|
            sh.cmd('rake', 'clean', 'build')
            sh.cmd('cp', 'build/respack.zip', local_path)
        end
    end

    def reconfigure_servers
        servers.each(&:api_sync!)
    end
end
