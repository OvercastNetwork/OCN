module Git
    module Event
        class << self
            def parse_request(request)
                data = JSON.parse(request.raw_post)

                if event = request.headers['X-GitHub-Event']
                    ::Git::Github::Event.parse(event, data)
                elsif request.headers['X-Gitlab-Event']
                    ::Git::Gitlab::Event.parse(data)
                end
            end
        end

        class Base
            abstract :provider

            attr_reader :data, :action

            def initialize(data, action = nil)
                @data = data
                @action = action
            end

            def namespace
            end

            def repo_name
            end

            def branch
            end
        end

        module User
            abstract :user_name, :user_url, :user_avatar_url
        end

        module Member
            include User
            abstract :member
        end

        module Assignee
            include User
            abstract :assignee
        end

        module Repository
            abstract :namespace, :repo_name, :repo_url, :repo_description

            def repo_full_name
                "#{namespace}/#{repo_name}"
            end
        end

        module Ref
            include Repository
            abstract :ref

            def branch
                ref =~ %r{^refs/heads/(.*)} and $1
            end

            def branch_url
                branch = self.branch and "#{repo_url}/tree/#{branch}"
            end

            def tag
                ref =~ %r{^refs/tags/(.*)} and $1
            end

            def tag_url
                tag = self.tag and "#{repo_url}/tree/#{tag}"
            end
        end

        module Commit
            include Repository
            abstract :commit_sha, :commit_message, :commit_url

            def commit_name(commit = nil)
                commit_sha(commit)[0..6]
            end
        end

        module Push
            include Ref
            include Commit
            abstract :commits, :forced?, :head_commit
        end

        module Comment
            include Repository
            abstract :comment_body, :comment_url
        end

        module PullRequest
            include Repository
            include Assignee
            abstract :pr_number, :pr_title, :pr_body, :pr_url

            def pr_description
                "##{pr_number} #{pr_title}"
            end
        end

        module Review
            include PullRequest
            abstract :review_body
        end

        module Issue
            include Repository
            include Assignee
            abstract :issue_number, :issue_title, :issue_body, :issue_url, :issue_label

            def issue_description
                "##{issue_number} #{issue_title}"
            end
        end
    end
end
