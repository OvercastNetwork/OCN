module Git
    module Gitlab
        module Event
            def self.parse(data)
                case data['object_kind']
                    when 'push', 'tag_push'
                        PushHook.new(data)
                    when 'issue'
                        IssueHook.new(data)
                    when 'note'
                        NoteHook.new(data)
                    when 'merge_request'
                        MergeRequestHook.new(data)
                end

                case data['event_name']
                    when 'project_create'
                        SystemHook.new(data)
                end
            end

            module User
                include ::Git::Event::User

                def user
                    data['user']
                end

                def user_name(user = self.user)
                    user['name']
                end

                def user_url(user = self.user)
                    "https://code.#{ORG::DOMAIN}/#{user['username']}"
                end

                def user_avatar_url(user = self.user)
                end
            end

            module Repository
                include ::Git::Event::Repository

                def project_id
                    data['project_id']
                end

                def project
                    @project ||= (data['project'] || ::Gitlab.project(project_id).to_h)
                end

                def repo_name
                    project['name']
                end

                def namespace
                    ns = project['namespace']
                    if ns.is_a? String
                        ns
                    else
                        ns['name']
                    end
                end

                def repo_url
                    project['web_url']
                end

                def repo_description
                    project['description']
                end
            end

            module Ref
                include ::Git::Event::Ref
                include Repository

                def ref
                    data['ref']
                end
            end

            module Commit
                include ::Git::Event::Commit
                include Repository

                def commit(commit = nil)
                    commit || data['commit']
                end

                def commit_sha(commit = nil)
                    commit(commit)['id']
                end

                def commit_message(commit = nil)
                    commit(commit)['message']
                end

                def commit_url(commit = nil)
                    commit(commit)['url']
                end
            end

            module Push
                include ::Git::Event::Push
                include Ref
                include Commit

                NULL_SHA = '0' * 40

                def head_commit
                    sha = data['checkout_sha'] and ::Gitlab.commit(data['project_id'], sha).to_h
                end

                def commits
                    data['commits']
                end

                def forced?
                    false
                end

                def user_name(user = nil)
                    if user
                        super(user)
                    else
                        data['user_name']
                    end
                end

                def user_url(user = nil)
                    super(user) if user
                end

                def user_avatar_url(user = nil)
                end

                def before
                    data['before']
                end

                def after
                    data['after']
                end

                def created?
                    before == NULL_SHA
                end

                def deleted?
                    after == NULL_SHA
                end
            end

            module PullRequest
                include ::Git::Event::PullRequest
                include Repository

                def pr
                    data['merge_request'] || data['object_attributes']
                end

                def pr_number
                    pr['iid']
                end

                def pr_title
                    pr['title']
                end

                def pr_body
                    pr['description']
                end

                def pr_url
                    pr['url']
                end
            end

            module Issue
                include ::Git::Event::Issue
                include Repository

                def issue
                    data['issue'] || data['object_attributes']
                end

                def issue_number
                    issue['iid']
                end

                def issue_title
                    issue['title']
                end

                def issue_url
                    issue['url']
                end

                def issue_body
                    issue['description']
                end
            end

            module Comment
                include ::Git::Event::Comment
                include Commit
                include Issue
                include PullRequest

                def comment
                    data['object_attributes']
                end

                def comment_body
                    comment['note']
                end

                def comment_url
                    comment['url']
                end
            end

            class Base < ::Git::Event::Base
                include User

                def provider
                    :gitlab
                end
            end

            class PushHook < Base
                include Push

                def action
                    if tag
                        if created?
                            return :tag_create
                        elsif deleted?
                            return :tag_delete
                        end
                    elsif branch
                        if created?
                            return :branch_create
                        elsif deleted?
                            return :branch_delete
                        end
                    end

                    :push
                end
            end

            class MergeRequestHook < Base
                include PullRequest

                def action
                    case pr['action']
                        when 'open'
                            :pr_open
                        when 'merge'
                            :pr_merge
                        when 'update'
                            # GitLab provides no way to determine what was updated, so we have to take a wild guess.
                            if pr['state'] == 'closed'
                                # If the MR is closed, assume that just happened
                                :pr_close
                            else
                                # Otherwise, just give up
                                :pr_update
                            end
                    end
                end
            end

            class NoteHook < Base
                include Comment

                def action
                    case comment['noteable_type']
                        when 'Commit'
                            :commit_comment
                        when 'Issue'
                            :issue_comment
                        when 'MergeRequest'
                            :pr_comment
                    end
                end
            end

            class IssueHook < Base
                include Issue

                def action
                    case issue['action']
                        when 'open'
                            :issue_open
                        when 'update'
                            if issue['state'] == 'closed'
                                :issue_close
                            else
                                :issue_update
                            end
                    end
                end
            end

            class SystemHook < Base
                include Repository

                def action
                    case data['event_name']
                        when 'project_create'
                            :repo_create
                    end
                end

                def user
                    @user ||= ::Gitlab.user(project['creator_id']).to_h
                end
            end

            class ProjectCreate < Base
                include Repository

                def action
                    :repo_create
                end

                def project
                    data
                end

                def user
                    @user ||= ::Gitlab.user(project['creator_id']).to_h
                end
            end
        end # Event
    end # Gitlab
end # Git
