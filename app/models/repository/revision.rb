class Repository
    include RequestCacheable

    attr_cached :revision_cache do
        {}
    end

    attr_cached :latest_revision do
        revisions(per_page: 1, page: 1)[0]
    end

    def revisions(per_page: nil, page: nil, since: nil, timeout: 5)
        opts = {}
        opts[:per_page] = per_page if per_page
        opts[:page] = page if page
        opts[:since] = since.iso8601 if since

        revs = timeout(timeout) do
            revisions_provider(**opts)
        end

        deployed = deployed_sha
        revs.each do |rev|
            rev.deployed = true if rev.sha == deployed
            revision_cache[rev.sha] = rev
        end

        if (per_page.nil? || per_page >= 1) && (page.nil? || page <= 1) && revs[0]
            revs[0].latest = true
            self.latest_revision = revs[0]
        end

        revs
    end

    def revision(sha, timeout: 5)
        revision_cache.cache(sha) do
            timeout(timeout) do
                if rev = revision_provider(sha)
                    rev.deployed = true if rev.sha == deployed_sha
                    rev
                end
            end
        end
    end

    def prefetch_authors(revs)
        name_field = "#{provider}_verified"

        users_by_name = User.in(name_field => revs.map(&:author_name))
            .hint(name_field => 1)
            .index_by{|user| user.__send__(name_field)}

        users_by_email = {}
        User.by_external_emails(*revs.map(&:author_email).reject(&:blank?)).each do |user|
            user.external_emails.each do |email|
                users_by_email[email] = user
            end
        end

        revs.each do |rev|
            rev.author = users_by_name[rev.author_name] || users_by_email[rev.author_email]
        end
    end

    def revisions_provider(**opts)
        raise NotImplementedError
    end

    def revision_provider(sha)
        raise NotImplementedError
    end

    class Revision
        attr_reader :author_name, :author_email, :message, :date, :sha
        attr_writer :deployed, :latest, :author

        def deployed?
            @deployed
        end

        def latest?
            @latest
        end

        def internal?
            message =~ /^\s*INT/ # Tag for internal (hidden) revisions
        end

        def initialize(provider:, author_name:, author_email:, message:, date:, sha:)
            @provider = provider
            @author_name = author_name
            @author_email = author_email
            @message = message
            @date = date
            @sha = sha
        end

        def sha_brief
            sha.slice(0, 7)
        end

        def author
            unless instance_variable_defined? :@author
                @author = User.find_by("#{@provider}_verified" => author_name) ||
                    User.by_external_email(author_email)
            end
            @author
        end
    end
end
