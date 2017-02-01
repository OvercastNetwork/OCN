module Mattermost
    module Git
        class Post < ::Mattermost::Post
            include ::Mattermost::Git::Formatting

            attr_reader :event

            def initialize(event:, icon: nil)
                super(username: "Git",
                      icon: icon && "emoji/#{icon}.png")
                @event = event
            end

            def text
                action = event.action and __send__(action)
            end

            def ping
                "Ping from repo #{repo_link}"
            end

            def repo_create
                "#{user_link} created new repository #{repo_link}:\n> #{preview(event.repo_description)}"
            end

            def repo_join
                "#{user_link} added #{user_link(event.member)} to repository #{repo_link}"
            end

            def repo_leave
                "#{user_link} removed #{user_link(event.member)} from repository #{repo_link}"
            end

            def branch_create
                "#{user_link} added branch `#{event.branch}` to #{repo_link}\n#{commits}"
            end

            def branch_delete
                "#{user_link} deleted branch `#{event.branch}` in #{repo_link}\n#{commits}"
            end

            def tag_create
                "#{user_link} added tag `#{event.tag}` to #{repo_link}\n#{commits}"
            end

            def tag_delete
                "#{user_link} deleted tag `#{event.tag}` in #{repo_link}\n#{commits}"
            end

            def push
                "#{user_link} #{event.forced? ? "force-pushed" : "pushed"} #{event.commits.size} commit#{event.commits.size > 1 ? 's' : ''} to `#{event.branch || event.tag}` in #{repo_link}\n#{commits}"
            end

            def commits
                if event.respond_to?(:commits) && !event.commits.empty?
                    event.commits.map{|commit| "    #{commit_with_message(commit)}\n" }.join
                elsif event.respond_to?(:head_sha) && event.respond_to?(:head_message)

                end
            end

            def commit_comment
                "#{user_link} commented on commit #{link(event.commit_name, event.comment_url)}:\n> #{preview(event.comment_body)}"
            end

            def pr_open
                "#{user_link} opened new pull request #{pr_link} in #{repo_link}:\n#{event.pr_body}"
            end

            def pr_update
                "#{user_link} updated pull request #{pr_link}"
            end

            def pr_assign
                "#{user_link} assigned #{user_link(event.assignee)} to pull request #{pr_link}"
            end

            def pr_close
                "#{user_link} closed pull request #{pr_link}"
            end

            def pr_merge
                "#{user_link} merged pull request #{pr_link}"
            end

            def pr_comment
                "#{user_link} commented on pull request #{pr_link}:\n> #{preview(event.comment_body)}"
            end

            def review_create
                blockquote("#{user_link} reviewed pull request #{pr_link} in #{repo_link}", event.review_body)
            end

            def issue_open
                "#{user_link} opened issue #{issue_link} in #{repo_link}:\n> #{preview(event.issue_body)}"
            end

            def issue_update
                "#{user_link} updated issue #{issue_link} in #{repo_link}"
            end

            def issue_label
                "#{user_link} added label `#{event.issue_label}` to issue #{issue_link} in #{repo_link}"
            end

            def issue_close
                "#{user_link} closed issue #{issue_link} in #{repo_link}"
            end

            def issue_assign
                "#{user_link} assigned #{user_link(event.assignee)} to issue #{issue_link} in #{repo_link}"
            end

            def issue_comment
                "#{user_link} commented on issue #{issue_link}:\n> #{preview(event.comment_body)}"
            end
        end
    end
end

