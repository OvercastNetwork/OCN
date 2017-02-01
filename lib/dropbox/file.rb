module Dropbox
    # {".tag"=>"file",
    #  "name"=>"uhc.xml",
    #  "path_lower"=>"/maps_dev/electroidfilms/uhc.xml",
    #  "parent_shared_folder_id"=>"dbsfid:AABD256cTRmYZksGfyPkZ4EpQBIEbxgNRFc",
    #  "id"=>"id:6EWlFQ2Er2YAAAAAAAAnnw",
    #  "client_modified"=>"2015-09-26T05:45:51Z",
    #  "server_modified"=>"2015-09-26T05:45:52Z",
    #  "rev"=>"841e2d38f20b",
    #  "size"=>3251,
    #  "sharing_info"=>
    #      {"read_only"=>false,
    #       "parent_shared_folder_id"=>"dbsfid:AABD256cTRmYZksGfyPkZ4EpQBIEbxgNRFc",
    #       "modified_by"=>"dbid:AAA8KT349sjw9pWu_8sY0YCSRwJgmqw6XbQ"}}

    class File < Entry
        field :parent_shared_folder_id, :rev, :size

        def client_modified
            Time.parse(json['client_modified'])
        end

        def server_modified
            Time.parse(json['server_modified'])
        end
    end
end
