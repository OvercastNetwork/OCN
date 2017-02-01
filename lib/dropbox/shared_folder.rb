module Dropbox
    # {"name"=>"Maps-ElectroidFilms",
    #  "shared_folder_id"=>"dbsfid:AADDyPjl52mZLwLlGo_daZoleixamjFmxAw",
    #  "access_type"=>{".tag"=>"owner"},
    #  "is_team_folder"=>false,
    #  "policy"=>
    #      {"acl_update_policy"=>{".tag"=>"editors"},
    #       "shared_link_policy"=>{".tag"=>"anyone"}}}

    class SharedFolder < Model
        field :name, :path_lower, :shared_folder_id, :access_type, :is_team_folder, :policy

        def folder
            unless @folder
                @folder = client.entry(path_lower)
                @folder.shared_folder = self
            end
            @folder
        end
        attr_writer :folder
    end
end
