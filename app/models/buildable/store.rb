module Buildable
    # Objects representing something that Buildable documents
    # are exported to and imported from.
    module Store
        class FileSystem
            attr :dir

            def initialize(dir)
                @dir = dir
            end

            def resolve(path)
                File.join(dir, path)
            end

            def glob(pattern)
                Dir.chdir(dir) do
                    Dir[pattern]
                end
            end

            def read(path)
                File.read(resolve(path))
            end

            def write(path, content)
                path = resolve(path)
                FileUtils.mkdir_p(File.dirname(path))
                File.write(path, content)
            end

            def delete(path)
                File.delete(resolve(path))
            end
        end

        class Memory
            attr :files

            def initialize(files)
                @files = files
            end

            def glob(pattern)
                files.keys.select do |path|
                    File.fnmatch?(pattern, path)
                end
            end

            def read(path)
                files[path] or raise Errno::ENOENT, path
            end

            def write(path, content)
                files[path] = content
            end

            def delete(path)
                files.delete(path)
            end
        end
    end
end
