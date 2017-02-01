require 'socket'
require 'rake'

# Worker for per-box tasks
class RepoWorker
    include QueueWorker

    queue Box.local.routing_key

    startup do
        # Subscribe to pull requests for all repos deployable to the local Box
        Repository.each do |repo|
            bind(topic, routing_key: repo.routing_key) if repo.deploy_to?(Box.local)
        end
    end

    handle PullRepoMessage do |msg|
        if repo = Repository[msg.repo_id]
            repo.local_deploy!(branch: msg.branch)
        else
            error "Unknown auto-deploy repo '#{msg.repo_id}'"
        end
        ack!(msg)
    end

    handle PullTranslationsMessage do |msg|
        Translation.local_deploy!(force: msg.force)
        ack!(msg)
    end
end
