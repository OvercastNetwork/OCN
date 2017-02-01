class Repository
    class Maps < Repository
        def handle_push(branch:)
            super
            if server = Server.for_maps_branch(branch)
                logger.info "Requesting maps pull for server #{server.id} that matches branch #{branch}"
                request_pull(branch: branch, box: server.box_obj)
            end
            true
        end

        def local_deploy!(branch: nil)
            super
            branch ||= self.branch
            if server = Server.for_maps_branch(branch)
                deploy_server_maps!(server)
            end
        end

        def deploy_server_maps!(server)
            if server.box_obj == Box.local
                logger.info "Pulling maps repo for server #{server.id}:#{server.name}"
                git_reset_hard!(path: server.local_maps_path, branch: server.name)
            end
        end
    end
end
