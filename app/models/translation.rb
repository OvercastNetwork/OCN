
# Configures localized file or directory from some repository.
#
# The ID is the path in the Crowdin project, while :repo: and :path:
# specify the source. If the source is a directory, :pattern: must
# also be specified, and will be used to glob files relative to
# the source.
#
# The sync! method uploads source files from the local box to Crowdin.
# It is assumed that the source repository is already deployed locally.
# New source files are created on Crowdin, but files are never deleted
# from Crowdin, this must be done manually.
#
# The local_deploy! method builds translations on Crowdin and downloads them to the
# local box. These are deployed locally to BASE_PATH. Each locale has a dir under
# BASE_PATH, and the complete Crowdin file structure is replicated under each locale.
# The modification time of BASE_PATH is used to detect freshness of the deployment.
#
# The sync! method is called in response to GitHub push notifications. If anything
# is uploaded, a PullTranslationsMessage is broadcast, which tells RepoWorker to
# run local_deploy! on each box. RepoWorker also runs local_deploy! periodically,
# since new translations may be available at any time, and Crowdin does not seem
# to have any notifications for this.

class Translation
    include MiniModel

    BASE_PATH = '/minecraft/translations'

    field :repo
    field :path
    field :files

    def translation_path
        File.join('/', id)
    end

    def local_path
        Repository[repo].join_path(path)
    end

    def file_map
        source = local_path
        if File.file? source
            {translation_path => source}
        elsif File.directory? source
            Dir.chdir(source) do
                Dir[files].mash do |file|
                    [File.join(translation_path, file), File.join(source, file)]
                end
            end
        else
            {}
        end
    end

    def in_dir(path: self.local_path, **opts, &block)
        ShellSession.run(**opts) do |sh|
            unless Dir.exists?(path)
                FileUtils.mkdir_p(path)
            end
            Dir.chdir(path) do
                block.call(sh)
            end
        end
    end

    def local_deploy!
        in_dir do |sh|
            zip = File.join(local_path, 'build.zip')
            sh.cmd('curl', '-o', zip, build_url)
            sh.cmd('unzip', zip)
            sh.cmd('rm', zip)
        end
    end

    def sync!(crowdin = CROWDIN[])
        new_dirs = []
        new_files = []
        changed_files = []

        file_map.each do |dest, source|
            entry = {
                dest: dest,
                source: source,
                export_pattern: File.join('%locale%', dest)
            }

            # Lookup the existing file on Crowdin
            file = crowdin.files[dest]

            if file.nil?
                # If the file doesn't exist, add it
                Logging.logger.info "Adding translated #{dest} from #{source}"
                new_files << entry

                # Crowdin does not create dirs automatically. We have to create them explicitly,
                # one at a time, in the right order, without duplicates.
                loop do
                    # Get the next parent dir
                    dir = File.dirname(dest)

                    # Break if we reach the root, or a dir that already exists, or a dir we are already creating
                    break if dir == '/' || dir == '.' || crowdin.files.key?(dir) || new_dirs.include?(dir)

                    # Prepend the dir to new_dirs (so parents are created first)
                    new_dirs.unshift(dir)
                end
            elsif file.last_updated < File.mtime(source).utc
                # If the file exists, but is out of date, update it
                Logging.logger.info "Updating translated #{dest} from #{source}"
                changed_files << entry
            end
        end

        # Post all changes in two big batches. Each call is limited to 20 files,
        # so we may have to split them up if we ever accumulate a lot of files.
        crowdin.update_file(changed_files) unless changed_files.empty?

        unless new_files.empty?
            # Add the new dirs first
            new_dirs.each{|dir| crowdin.add_directory(dir) }

            # Set some options and add the new files
            # We use the "android" type just because it's an XML format that fits our needs
            opts = {type: 'android',
                    content_segmentation: false}
            crowdin.add_file(new_files, **opts)
        end

        !(changed_files.empty? && new_files.empty?)
    end

    class << self
        def sync!
            crowdin = CROWDIN[]
            map{|t| t.sync!(crowdin)}.any?
        end

        # Tell Crowdin to build the project, if necessary.
        # Crowdin will ignore this if there are no changes.
        def build!
            crowdin = CROWDIN[]
            if crowdin.project.last_build < crowdin.project.last_activity
                Logging.logger.info "Building translations"
                crowdin.export_translations

                pull!
            end
        end

        def pull!
            Logging.logger.info "Pulling translations on all boxes"
            Publisher::FANOUT.publish(PullTranslationsMessage.new)
        end

        def local_deploy!(path: BASE_PATH, force: false, **opts)
            crowdin = CROWDIN[]
            ShellSession.run(**opts) do |sh|
                # Ensure the target dir exists
                FileUtils.mkdir_p(path)

                # After deploying, the mod time of the target dir is set to the build time.
                # We use this to detect if deployment is needed.
                return if !force && crowdin.project.last_build <= File.mtime(path)

                Logging.logger.info "Downloading translations from Crowdin"

                Dir.mktmpdir do |tmp|
                    zip = File.join(tmp, 'build.zip')
                    unzip = File.join(tmp, 'build')

                    # Download latest build.zip
                    crowdin.download_translation('all', output: zip)

                    # Unzip to an empty temp dir
                    sh.cmd('unzip', '-qo', zip, '-d', unzip)

                    # Fix file perms (Crowdin sets everything to 777)
                    sh.cmd('chmod', '-R', 'o-wx', unzip)

                    # Use rsync to mirror the temp dir to the permanent one.
                    # This should make the update as smooth and efficient as possible,
                    # and ensure that removed files are properly cleaned up.
                    sh.cmd('rsync', '--archive', '--delete', File.join(unzip, '/'), path)
                end

                # Set the mod time of the target dir to match the build time.
                FileUtils.touch(path, mtime: crowdin.project.last_build)
            end
        end
    end
end
