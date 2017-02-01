class Repository
    class Data < Repository
        DEPLOY_BRANCH = 'master'

        def models_path(path = self.absolute_path)
            File.join(path, 'models')
        end

        def make_store(path = self.absolute_path)
            Buildable::Store::FileSystem.new(models_path(path))
        end

        def after_deploy(branch:)
            local_build!(branch: branch, dry: false)
        end

        def local_build!(branch: DEPLOY_BRANCH, dry: true)
            super

            with_temporary_git_checkout(branch: branch) do |_, dir|
                load_models(path: dir, dry: dry)
            end
        end

        def load_models(models: nil, path: self.absolute_path, dry: false)
            Buildable.load_models(models: models, store: make_store(path), dry: dry)
        end

        def save_models(models: nil, path: self.absolute_path)
            Buildable.save_models(models: models, store: make_store(path), dry: false)
        end
    end
end
