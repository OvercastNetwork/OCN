class Repository
    module GitHub
        def default_host
            'github.com'
        end

        def revisions_provider(**opts)
            ::GITHUB.repos.commits.list(namespace, repo, sha: branch, **opts).map do |json|
                Revision.new(json)
            end
        end

        def revision_provider(sha)
            Revision.new(::GITHUB.repos.commits.get(namespace, repo, sha))
        end

        class Revision < Repository::Revision
            def initialize(json)
                super(
                    provider: :github,
                    author_name: json.author ? json.author.login : json.commit.author.name,
                    author_email: json.commit.author.email,
                    message: json.commit.message,
                    date: Time.parse(json.commit.committer.date),
                    sha: json.sha
                )
            end
        end
    end
end
