class PullRepoMessage < BaseMessage
    field :repo_id
    field :branch

    def initialize(repo = nil, branch: nil, **opts)
        if repo
            opts = {
                routing_key: repo.routing_key,
                persistent: true,
                expiration: 1.day,
            }.merge(opts)

            super(payload: {repo_id: repo.id, branch: branch}, **opts)
        else
            super()
        end
    end
end
