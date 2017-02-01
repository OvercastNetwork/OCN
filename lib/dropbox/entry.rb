module Dropbox
    class Entry < Model
        field :id, :name, :path_lower, :sharing_info, :parent_shared_folder_id

        def path
            Pathname.new(path_lower)
        end

        def <=>(entry)
            id <=> entry.id
        end

        class << self
            def create(client, json)
                case type = json['.tag']
                    when 'folder'
                        Dropbox::Folder.new(client, json)
                    when 'file'
                        Dropbox::File.new(client, json)
                    else
                        raise "Unknown entry type '#{type}'"
                end
            end
        end
    end
end
