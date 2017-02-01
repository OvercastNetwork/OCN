module Git
    module Github
        module Event
            def self.parse(event, data)
                case event
                    when 'ping'
                        Ping.new(data)
                    when 'repository'
                        RepositoryEvent.new(data)
                    when 'member'
                        MemberEvent.new(data)
                    when 'create'
                        CreateEvent.new(data)
                    when 'delete'
                        DeleteEvent.new(data)
                    when 'push'
                        PushEvent.new(data)
                    when 'pull_request'
                        PullRequestEvent.new(data)
                    when 'pull_request_review'
                        ReviewEvent.new(data)
                    when 'pull_request_review_comment'
                        ReviewComment.new(data)
                    when 'commit_comment'
                        CommitComment.new(data)
                    when 'issues'
                        IssueEvent.new(data)
                    when 'issue_comment'
                        IssueComment.new(data)
                end # case event
            end # self.parse

            module User
                include ::Git::Event::User

                def user
                    data['sender']
                end

                def user_name(user = self.user)
                    user['login']
                end

                def user_url(user = self.user)
                    user['html_url']
                end

                def user_avatar_url(user = self.user)
                    # Broken - size doesn't work
                    # user['avatar_url'] + "&s=18"
                end
            end

            module Member
                include ::Git::Event::Member
                include User

                def member
                    data['member']
                end
            end

            module Assignee
                include ::Git::Event::Assignee
                include User

                def assignee
                    data['assignee']
                end
            end

            module Repository
                include ::Git::Event::Repository

                def repo
                    data['repository']
                end

                def repo_name
                    repo['name']
                end

                def repo_owner
                    repo['owner']
                end

                def namespace
                    repo_owner['name']
                end

                def repo_full_name
                    repo['full_name']
                end

                def repo_url
                    repo['html_url']
                end

                def repo_description
                    repo['description']
                end
            end

            module Ref
                include ::Git::Event::Ref
                include Repository

                def ref
                    data['ref']
                end

                def ref_type
                    data['ref_type']
                end
            end

            module Commit
                include ::Git::Event::Commit
                include Repository

                def commit_sha(commit)
                    commit['id']
                end

                def commit_message(commit)
                    commit['message']
                end

                def commit_url(commit)
                    commit['url']
                end
            end

            module Push
                include ::Git::Event::Push
                include Ref
                include Commit

                def head_commit
                    data['head_commit']
                end

                def commits
                    commits = data['commits']
                    commits = [head_commit].compact if commits.empty?
                    commits
                end

                def forced?
                    data['forced']
                end
            end

            module Comment
                include ::Git::Event::Comment
                include Repository

                def comment
                    data['comment']
                end

                def comment_body
                    comment['body']
                end

                def comment_url
                    comment['html_url']
                end
            end

            module PullRequest
                include ::Git::Event::PullRequest
                include Repository
                include Assignee

                def pr
                    data['pull_request']
                end

                def pr_number
                    pr['number']
                end

                def pr_title
                    pr['title']
                end

                def pr_body
                    pr['body']
                end

                def pr_url
                    pr['html_url']
                end

                def pr_merged?
                    !!pr['merged']
                end
            end

            module Review
                include ::Git::Event::Review
                include PullRequest

                def review
                    data['review']
                end

                def review_body
                    review['body']
                end
            end

            module Issue
                include ::Git::Event::Issue
                include Repository
                include Assignee

                def issue
                    data['issue']
                end

                def issue_number
                    issue['number']
                end

                def issue_title
                    issue['title']
                end

                def issue_url
                    issue['html_url']
                end

                def issue_body
                    issue['body']
                end

                def issue_label
                    data['label']['name']
                end
            end

            class Base < ::Git::Event::Base
                include User

                def provider
                    :github
                end
            end

            class Ping < Base
                include Repository

                def action
                    :ping
                end
            end

            class RepositoryEvent < Base
                include Repository

                def action
                    case data['action']
                        when 'created'
                            :repo_create
                    end
                end
            end

            class MemberEvent < Base
                include Member
                include Repository

                def action
                    case data['action']
                        when 'added'
                            :repo_join
                        when 'removed'
                            :repo_leave
                    end
                end
            end

            class RefEvent < Base
                include Ref

                alias_method :branch, :ref
                alias_method :tag, :ref
            end

            class CreateEvent < RefEvent
                include Ref

                def action
                    case ref_type
                        when 'branch'
                            :branch_create
                        when 'tag'
                            :tag_create
                    end
                end
            end

            class DeleteEvent < RefEvent
                include Ref

                def action
                    case ref_type
                        when 'branch'
                            :branch_delete
                        when 'tag'
                            :tag_delete
                    end
                end
            end

            class PushEvent < Base
                include Push

                def action
                    :push unless data['deleted']
                end
            end

            class PullRequestEvent < Base
                include PullRequest

                def action
                    case data['action']
                        when 'opened'
                            :pr_open
                        when 'assigned'
                            :pr_assign
                        when 'closed'
                            if pr['merged']
                                :pr_merge
                            else
                                :pr_close
                            end
                    end
                end
            end

            class ReviewEvent < Base
                include Review

                def action
                    case data['action']
                        when 'submitted'
                            :review_create
                    end
                end
            end

            class ReviewComment < Base
                include Review
                include Comment

                def action
                    case data['action']
                        when 'created'
                            :pr_comment
                    end
                end
            end

            class CommitComment < Base
                include Commit
                include Comment

                def commit_name(commit = nil)
                    if commit
                        super(commit)
                    else
                        comment['commit_id'][0..6]
                    end
                end

                def action
                    case data['action']
                        when 'created'
                            :commit_comment
                    end
                end
            end

            class IssueEvent < Base
                include Issue

                def action
                    case data['action']
                        when 'opened'
                            :issue_open
                        when 'closed'
                            :issue_close
                        when 'labeled'
                            :issue_label
                        when 'assigned'
                            :issue_assign
                    end
                end
            end

            class IssueComment < Base
                include Issue
                include Comment

                def action
                    case data['action']
                        when 'created'
                            :issue_comment
                    end
                end
            end
        end # Event
    end # Github
end # Git
