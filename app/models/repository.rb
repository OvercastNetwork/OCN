require_dependencies 'repository/*'

class Repository
    include MiniModel
    include Git

    BASE_PATH = '/minecraft/repo'

    field :title            # Human-readable name
    alias_method :name, :title
    field :description      # One sentence description
    field :visible?         # Show on revisions page?
    field :provider         # Application hosting the repo
    field :host             # Hostname of the application
    field :namespace        # Namespace/Organization
    field :repo             # Repo name
    field :open?            # Repo public?
    field :path             # Local path to repo on servers
    field :branch           # Branch name
    field :deployed         # File containing deployed SHA
    field :auto_deploy?     # Automatically pulled onto servers?
    field :services         # List of Box.services that require this repo (default is all boxes)

    define_callbacks :deploy

    class << self
        def by_repo(repo)
            find{|r| r.repo == repo}
        end

        def for_git_event(event)
            where_attrs(provider: event.provider,
                        namespace: event.namespace,
                        repo: event.repo_name)
        end
    end

    def after_create
        case provider
            when :github
                extend GitHub
            when :gitlab
                extend GitLab
            else
                raise "Unknown provider '#{provider}'"
        end
    end

    def description_html
        MARKDOWN.render(self.description)
    end

    def repo
        @repo || self.id.to_s
    end

    def title
        @title || repo
    end

    def default_host
        raise NotImplementedError
    end

    def host
        @host || default_host
    end

    def public_url
        "https://#{host}/#{namespace}/#{repo}"
    end

    def clone_url
        "git@#{host}:#{namespace}/#{repo}.git"
    end

    def branch
        @branch || 'master'
    end

    def path
        @path || self.id.to_s
    end

    def pathname
        @pathname ||= Pathname.new(path)
    end

    def absolute_path
        if self.pathname.absolute?
            self.path
        else
            File.join(BASE_PATH, self.path)
        end
    end

    def absolute_pathname
        if self.pathname.absolute?
            self.pathname
        else
            Pathname.new(File.join(BASE_PATH, self.path))
        end
    end

    def join_path(*path)
        File.join(self.absolute_path, *path)
    end

    # SHA of currently deployed version, or nil if unknown
    def deployed_sha
        if self.deployed && File.exists?(self.deployed)
            File.read(self.deployed).strip
        elsif File.directory?("#{self.absolute_path}/.git")
            ::Git.open(self.absolute_path).object("HEAD").sha
        end
    end

    def all_branches?
        @branch == '*'
    end

    def deploy_branch?(branch)
        all_branches? || branch == self.branch
    end

    def deploy_to?(box)
        services.nil? || services.any?{|service| box.services.include?(service) }
    end

    ####################
    # Build/Deployment #
    ####################

    # Build whatever is in this repo and return true on success
    def local_build!(branch: nil, dry: false)
        # Override
    end

    # Handle a push notification from Github
    def handle_push(branch:)
        if auto_deploy? && deploy_branch?(branch)
            logger.info "Pulling repo #{title}/#{branch}"
            request_pull(branch: branch)
        end
        true
    end

    # Deploy the given branch of this repo to the local box, if it is configured to do so
    def local_deploy!(branch: nil)
        branch ||= self.branch
        if deploy_branch?(branch) && deploy_to?(Box.local)
            logger.info "Pulling auto-deploy repo #{name} from branch #{branch} to local path #{absolute_path}"
            run_callbacks :deploy do
                git_reset_hard!(branch: branch)
                after_deploy(branch: branch)
            end
        end
    end

    def after_deploy(branch:)
        # Would be nice to use callbacks for this,
        # but there's no way to pass the branch.
    end

    ########
    # AMQP #
    ########

    # Topic exchange key
    def routing_key
        "repo.#{self.id}"
    end

    # Request a pull of this repo on the given box or all boxes
    def request_pull(box: nil, branch: self.branch)
        msg = PullRepoMessage.new(self, branch: branch)

        if box
            Publisher::DIRECT.publish(msg, routing_key: box.routing_key)
        else
            Publisher::TOPIC.publish(msg)
        end
    end
end

if Rails.env.development?
    # Bit of a hack to restrore the static data after the model auto-reloads
    load Rails.root.join('config', 'initializers', 'repositories.rb')
end
