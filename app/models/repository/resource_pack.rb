class Repository
    class ResourcePack < Repository
        def local_build!(branch: nil, dry: true)
            super
            if rp = ::ResourcePack.for_branch(branch)
                rp.build
                rp.update_digest
                rp.save!
                rp.reconfigure_servers
            end
        end

        def after_deploy(branch:)
            local_build!(branch: branch)
        end
    end
end
