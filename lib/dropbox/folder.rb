module Dropbox
    # {".tag"=>"folder",
    #  "name"=>"Plastix",
    #  "path_lower"=>"/maps_dev/plastix",
    #  "id"=>"id:c835od64uQwAAAAAAACfJA",
    #  "shared_folder_id"=>"dbsfid:AAANNVfL2rMjTTcsTKYKwTaw__c7TcaZUh8",
    #  "sharing_info"=>
    #      {"read_only"=>false,
    #       "shared_folder_id"=>"dbsfid:AAANNVfL2rMjTTcsTKYKwTaw__c7TcaZUh8"}}

    class Folder < Entry
        field :shared_folder_id

        def join(*paths)
            joined = path_lower
            paths.each do |path|
                joined << "/#{path.sub(/^\//, '')}"
            end
            joined
        end

        def entries(*paths)
            @entries ||= client.entries(join(*paths))
        end

        def entry(*paths)
            client.entry(join(*paths))
        end

        def shared?
            !shared_folder_id.nil?
        end

        def shared_folder
            unless @shared_folder
                @shared_folder = client.shared_folder(shared_folder_id) if shared_folder_id
                @shared_folder.folder = self
            end
            @shared_folder
        end
        attr_writer :shared_folder

        def share(member_policy: 'team', acl_update_policy: 'owner', shared_link_policy: 'members', force_async: false)
            result = client.post(
                '/2/sharing/share_folder',
                path: path_lower,
                member_policy: member_policy,
                acl_update_policy: acl_update_policy,
                shared_link_policy: shared_link_policy,
                force_async: force_async
            )
            json['shared_folder_id'] = result['shared_folder_id']
            result
        end

        def unshare(leave_a_copy: false)
            client.post(
                '/2/sharing/unshare_folder',
                shared_folder_id: shared_folder_id,
                leave_a_copy: leave_a_copy
            )
        end

        def members
            @members ||= client.post(
                '/2/sharing/list_folder_members',
                shared_folder_id: shared_folder_id
            )['users'].map{|json| Member.new(client, json, self) }
        end

        def member(account)
            account = account.account_id if account.is_a? Account
            members.find{|m| m.account_id == account }
        end

        def member?(account)
            !member(account).nil?
        end

        def _member_json(account, access_level)
            account = account.account_id if account.is_a? Account
            {
                member: {
                    '.tag' => 'dropbox_id',
                    dropbox_id: account
                },
                access_level: {
                    '.tag' => access_level
                }
            }
        end

        def add_member(*accounts, access_level: 'viewer', quiet: false, custom_message: nil)
            json = {
                shared_folder_id: shared_folder_id,
                members: accounts.map{|account| _member_json(account, access_level) },
                quiet: quiet
            }
            json[:custom_message] = custom_message if custom_message
            client.post(
                '/2/sharing/add_folder_member',
                **json
            )
        end

        def update_member(account, access_level: 'viewer')
            account = account.account_id if account.is_a? Account
            client.post(
                '/2/sharing/update_folder_member',
                shared_folder_id: shared_folder_id,
                **_member_json(account, access_level)
            )
        end

        def remove_member(account, leave_a_copy: false)
            account = account.account_id if account.is_a? Account
            client.post(
                '/2/sharing/remove_folder_member',
                shared_folder_id: shared_folder_id,
                member: {
                    '.tag' => 'dropbox_id',
                    dropbox_id: account
                },
                leave_a_copy: leave_a_copy
            )
        end

        # {"access_type"=>{".tag"=>"editor"},
        #  "user"=>
        #      {"account_id"=>"dbid:AAA0DCigN2zopzaM0LfqFQmZph6G6KXNvC0",
        #       "same_team"=>false}}
        class Member < Model
            attr :folder
            def initialize(client, json, folder)
                super(client, json)
                @folder = folder
            end

            def access_type
                json['access_type']['.tag']
            end

            def same_team?
                json['user']['same_team']
            end

            def account_id
                json['user']['account_id']
            end

            def account
                @account ||= client.account(account_id)
            end

            def remove
                folder.remove_member(account_id)
            end
        end
    end
end
