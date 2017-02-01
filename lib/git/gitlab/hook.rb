module Git
    module Gitlab
        module Hook

            OPTIONS = {
                "push_events" => true,
                "issues_events" => true,
                "merge_requests_events" => true,
                "tag_push_events" => true,
                "note_events" => true,
                "build_events" => false,
                "pipeline_events" => false,
                "wiki_page_events" => false,
                "enable_ssl_verification" => true
            }

            class << self
                def project(p)
                    if p.respond_to?(:id)
                        p
                    else
                        ::Gitlab.project(p)
                    end
                end

                def project_id(p)
                    if p.respond_to?(:id)
                        p.id
                    else
                        p
                    end
                end

                def project_hook(project)
                    url = Admin::GitController.event_url
                    ::Gitlab.project_hooks(project_id(project)).find{|h| h.url == url }
                end

                def options
                    OPTIONS.merge("token" => GITLAB_WEBHOOK_TOKEN)
                end

                def hook_project(project)
                    project_id = project_id(project)
                    project = project(project)

                    if hook = project_hook(project_id)
                        unless OPTIONS.all?{|k, v| hook.__send__(k) == v }
                            ::Gitlab.edit_project_hook(project_id, hook.id, Admin::GitController.event_url, options)
                        end
                    else
                        ::Gitlab.add_project_hook(project_id, Admin::GitController.event_url, options)
                        return Gitlab::Event::ProjectCreate.new((project || ::Gitlab.project(project_id)).to_h)
                    end
                    nil
                end

                def unhook_project(project)
                    project_id = project_id(project)
                    if hook = project_hook(project_id)
                        ::Gitlab.delete_project_hook(project_id, hook.id)
                    end
                end

                def hook_all_projects
                    ::Gitlab.projects.map do |project|
                        hook_project(project)
                    end.compact
                end

                def unhook_all_projects
                    ::Gitlab.projects.each do |project|
                        unhook_project(project)
                    end
                end
            end # << self
        end # Hook
    end # Gitlab
end # Git
