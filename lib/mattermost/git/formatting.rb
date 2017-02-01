module Mattermost
    module Git
        module Formatting
            include ::Mattermost::Formatting

            def user_link(user = event.user)
                text = event.user_name(user)

                if url = event.user_url(user)
                    text = link(text, url)
                end

                if avatar = event.user_avatar_url(user)
                    "#{image(avatar)} #{text}"
                else
                    text
                end
            end

            def repo_link(url = nil)
                link(event.repo_full_name, url || event.repo_url)
            end

            def commit_link(commit, url = nil)
                link(event.commit_name(commit), url || event.commit_url(commit))
            end

            def commit_with_message(commit)
                "#{commit_link(commit)} #{preview(event.commit_message(commit))}"
            end

            def pr_link(url = nil)
                link(event.pr_description, url || event.pr_url)
            end

            def issue_link(url = nil)
                link(event.issue_description, url || event.issue_url)
            end
        end
    end
end

