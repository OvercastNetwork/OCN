class Repository
    module GitLab
        def default_host
            "code.#{ORG::DOMAIN}"
        end

        def gitlab_name_escaped
            URI.escape("#{namespace}/#{repo}", URI::PATTERN::RESERVED)
        end

        def revisions_provider(**opts)
            opts = {ref_name: branch}.merge(**opts)
            opts[:page] and opts[:page] -= 1
            ::Gitlab.commits(gitlab_name_escaped, opts).map do |commit|
                Revision.new(commit)
            end
        end

        def revision_provider(sha)
            Revision.new(::Gitlab.commit(gitlab_name_escaped, sha))
        end

        class Revision < Repository::Revision
            def initialize(commit)
                super(
                    provider: :gitlab,
                    author_name: commit.author_name,
                    author_email: commit.author_email,
                    message: commit.message,
                    date: Time.parse(commit.created_at),
                    sha: commit.id
                )
            end
        end
    end
end
