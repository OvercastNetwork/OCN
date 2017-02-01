module Admin
    class GitController < BaseController
        HMAC_DIGEST = OpenSSL::Digest.new('sha1')

        def self.general_permission
            # Perms are enforced by #verify_request
            Permissions.everybody_permission
        end

        skip_before_action :verify_authenticity_token, only: [:event] # Skip CSRF
        skip_before_filter :authenticate_admin, only: [:event]

        def self.event_url
            Rails.application.routes.url_for(controller: controller_path, action: 'event')
        end

        def event
            if request.headers['X-Hub-Signature'] =~ /sha1=(.+)/
                signature = $1
                body = request.body.read
                digest = OpenSSL::HMAC.hexdigest(HMAC_DIGEST, GITHUB_WEBHOOK_SECRET, body)
                unless signature && digest && signature == digest
                    Logging.logger.error "GitHub webhook failed HMAC verification (signature=#{signature} digest=#{digest}):\n#{body}"
                    render status: 403, json: {}
                    return
                end
            elsif token = request.headers['X-Gitlab-Token']
                unless token == GITLAB_WEBHOOK_TOKEN
                    Logging.logger.error "GitLab webhook sent wrong token: #{token.inspect}"
                    render status: 403, json: {}
                    return
                end
            else
                Logging.logger.error "Unrecognized webhook request"
                render status: 400, json: {}
                return
            end

            handle_event
        end

        protected

        def handle_event
            success = true
            out = Logging.capture do
                if event = Git::Event.parse_request(request)
                    success = false unless handle_alert(event)

                    if event.is_a?(Git::Event::Push) && event.branch
                        success = false unless handle_push(event)
                    end

                    if event.is_a?(Git::Gitlab::Event::SystemHook) && event.action == :repo_create
                        begin
                            Git::Gitlab::Hook.hook_project(event.project)
                        rescue Gitlab::Error::Forbidden
                            Logging.logger.warn "Forbidden from creating webhook for GitLab project #{event.repo_full_name}"
                        end
                    end
                else
                    Logging.logger.error "Unrecognized webhook request"
                    success = false
                end
            end
            render status: success ? 200 : 422, text: out, content_type: 'text/plain'
        end

        def handle_push(event)
            success = true

            Logging.logger.info "Handling push for repo #{event.repo_full_name} branch #{event.branch}"

            Repository.for_git_event(event).each do |repo|
                begin
                    success = false unless repo.handle_push(branch: event.branch)
                rescue => ex
                    Logging.logger.error "Failed to handle push for repo #{repo.title}: #{ex.format_long}"
                end
            end

            Translation.sync! and Translation.build!

            success
        end

        def handle_alert(event)
            Raven.capture do
                internal = event.is_a?(Git::Event::Push) && event.commits.any?{|commit| event.commit_message(commit) =~ /^INT/ }

                channels = []
                Mattermost::Hook.start do |http|
                    CHAT_CHANNELS[Rails.env].each do |channel_name, channel|
                        next if internal && channel[:public]

                        if repo_info = channel[:repos][event.repo_name]
                            event_filter = repo_info[:events] || -> (ev) { true }
                            branch_filter = repo_info[:branches] || -> (br) { br == 'master' }

                            if event_filter[event.action] && (event.branch.nil? || branch_filter[event.branch])
                                channels << channel_name
                                post = Mattermost::Git::Post.new(event: event, icon: REPOS[event.repo_name][:icon])
                                http.request channel[:hook].request(post)
                            end
                        end
                    end
                end

                Logging.logger.info "Alerted channels #{channels.join(', ')}" unless channels.empty?
                true
            end
        rescue
            Logging.logger.error "Failed to send alerts for event #{event}"
            false
        end

        REPOS = Hash.default(
            icon: 'github'
        ).merge(
            'SportBukkit' => {icon: 'cowboy'},
            'ProjectAres' => {icon: 'cowboy'},
        )

        NO_EVENTS = {
            events: -> (ev) { false }
        }

        SOME_EVENTS = {
            events: -> (ev) { ev =~ /^(push|pr_open|pr_close|pr_merge)$/ }
        }

        MORE_EVENTS = {
            events: -> (ev) { ev =~ /^(push|pr_open|pr_close|pr_merge|issue_open|issue_close)$/ }
        }

        ALL_EVENTS = {
            events: -> (ev) { ev !~ /^(pr_comment)$/ }
        }

        CHAT_CHANNELS = Hash.default{ {} }

        CHAT_CHANNELS['development'] = {
            test: {
                hook: Mattermost::Hook.new('...'),
                repos: Hash.default(
                    events: -> (ev) { true },
                    branches: -> (br) { true },
                ),
            }
        }

        CHAT_CHANNELS['production'] = {
            alerts: {
                hook: Mattermost::Hook.new('...'),
                public: true,
                repos: {
                    # Public channel gets only PRs and commits from important repos.
                    'ProjectAres' => SOME_EVENTS,
                    'SportBukkit' => SOME_EVENTS,
                }
            },
            development: {
                hook: Mattermost::Hook.new('fpy4eek4wpyb3m757k13eckkao'),
                repos: Hash.default(MORE_EVENTS).merge(
                    # Devs get PRs, commits, and issues from all repos, except Data and Maps,
                    # which they can already see in other channels. They also get comments
                    # from the big code repos, and the internal issue repo.
                    'ProjectAres' => ALL_EVENTS,
                    'SportBukkit' => ALL_EVENTS,
                )
            },
        }
    end
end
