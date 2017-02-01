class Repository
    module Git
        extend ActiveSupport::Concern

        included do
        end # included do
        
        module ClassMethods
        end # ClassMethods

        def in_dir(path: self.absolute_path, **opts, &block)
            ShellSession.run(**opts) do |sh|
                unless Dir.exists?(path)
                    FileUtils.mkdir_p(path)
                end
                Dir.chdir(path) do
                    block.call(sh)
                end
            end
        end

        def git_clone!(path: self.absolute_path, branch: self.branch, **opts)
            url = clone_url
            ShellSession.run(**opts) do |sh|
                if branch
                    sh.cmd('git', 'clone', '--single-branch', '--branch', branch, url, path)
                else
                    sh.cmd('git', 'clone', url, path)
                end
            end
        end

        def git_fetch!(path: self.absolute_path, remote: 'origin', branch: self.branch, **opts)
            if File.exists?(File.join(path, '.git'))
                in_dir(path: path, **opts) do |sh|
                    sh.cmd('git', 'fetch', '-fu', remote, "+#{branch}:#{branch}")
                end
            else
                git_clone!(path: path, branch: branch)
            end
        end

        # Ensure the repository is cloned, fetched, and reset to the given branch,
        # or the default branch if none is given.
        def git_reset_hard!(path: self.absolute_path, remote: 'origin', branch: self.branch, **opts)
            git_fetch!(path: path, remote: remote, branch: branch, **opts)
            in_dir(path: path, **opts) do |sh|
                sh.cmd('git', 'checkout', branch)
                sh.cmd('git', 'reset', '--hard', 'HEAD')
            end
        end

        # Checkout the given/default branch to a temporary directory, without altering
        # the repository itself. The temporary directory is made the current working
        # directory and its path is passed to the given block. After the block returns,
        # the prior CWD is restored and the temporary directory is deleted.
        #
        # The checkout uses 'git clone' on the local repository. It does not fetch anything
        # from any remotes. It also uses the '--shared' option, which means the temporary
        # repository shares metadata with the one it was cloned from. This makes it very
        # fast, but it's probably not a good idea to do any writing operations on the
        # temporary repo.
        def with_temporary_git_checkout(branch: self.branch, **opts, &block)
            ShellSession.run(**opts) do |sh|
                # I'd rather use the block form of mktmpdir, but somehow when it's run from the web server,
                # the temporary directory disappears before mktmpdir can delete it, and it raises ENOENT.
                # It works fine if I run it from the shell, but it fails when run from the controller.
                # And this only happens in production, not on my dev machine.
                begin
                    tmp = Dir.mktmpdir
                    git_clone!(path: tmp, branch: branch)
                    Dir.chdir(tmp) do
                        block.call(sh, tmp)
                    end
                ensure
                    FileUtils.remove_entry(tmp) if tmp && Dir.exists?(tmp)
                end
            end
        end
    end # Git
 end
