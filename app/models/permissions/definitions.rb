module Permissions
    module Definitions
        ROOT = Builders::Root.new do
            domain :global do
                # Permission that everybody has implicitly
                node :everybody do
                    option true
                end
            end

            domain :site do
                # Nobody should have this permission explicitly, but admins have it implicitly since they have all perms
                boolean :admin, "manage the website"

                # The default group has this permission, but it can be overridden to
                # create users that cannot login normally, only with an API key.
                boolean :login, "login to the website with a password"
            end

            domain :api do
                boolean :key, "generate an API key and use it to authenticate"
                boolean :verify, "verify API requests without altering any data"
                boolean :commit, "alter data through API requests"
            end

            domain :user do
                branch :profile do
                    branch :verified do
                        ownable :edit, "edit verified profile fields"
                    end
                end
            end

            domain :tournament do
                boolean :admin, "access the tournament admin area"
                boolean :manage, "manage tournaments (overrides all other tournamemt permissions)"
                boolean :participate, "participate in tournaments"
                boolean :accept, "accept tournament registrations"
                boolean :decline, "decline tournament registrations"
            end

            domain :stream do
                boolean :admin, "access the stream admin area"
                boolean :manage, "manage streams (overrides all other stream permissions)"
            end

            domain :banner do
                boolean :admin, "manage the banner admin area"
            end

            domain :punishment do
                boolean :manage, "manage punishments (overrides all other punishment permissions)"
                ownable :delete, "delete punishments"
                ownable [:sort, :punisher], "sort punishments by punisher"

                types = {
                    warn: "warning",
                    kick: "kick",
                    ban: "ban",
                    forum_warn: "forum warning",
                    forum_ban: "forum ban",
                    tourney_ban: "tournament ban"
                }

                states = [:stale, :inactive, :automatic, :contested]

                actions = {
                    view: "view",
                    index: "list"
                }

                branch :create do
                    # punishment.create.<type>
                    types.each do |id, name|
                        boolean id, "issue #{name}s"
                    end
                end

                branch :distinguish_status do
                    # punishment.distinguish_status.<status>
                    states.each do |state|
                        ownable state, "see #{state} status"
                    end
                end

                actions.each do |act_id, act_name|
                    branch act_id do
                        branch :type do
                            # punishment.<action>.type.<type>
                            types.each do |type_id, type_name|
                                ownable type_id, "#{act_name} #{type_name}s"
                            end
                        end

                        branch :status do
                            # punishment.<action>.status.<status>
                            states.each do |state|
                                ownable state, "#{act_name} #{state} punishments"
                            end
                        end
                    end
                end
            end

            # Welcome to hell (reports & appeals)
            begin
                # Model-specific actions
                model_actions = {
                    report: {
                        punish: "issue punishments for",
                    },
                    appeal: {
                        expire: "expire punishments for",
                        appeal: "grant appeals for",
                        unappeal: "revoke appeals for",
                    }
                }

                # Actions that apply to any model
                generic_actions = {
                    comment: "comment on",
                }

                # Actions that change state
                transitional_actions = {
                    open: "open",
                    close: "close",
                    lock: "lock",
                    unlock: "unlock",
                    escalate: "escalate",
                }

                # Actions that never depend on state
                stateless_actions = {
                    index: "list",
                    view: "view",
                }

                # States and the actions that transition into them
                states = {
                    closed: :close,
                    locked: :lock,
                    escalated: :escalate,
                }

                model_actions.keys.each do |model|
                    domain model do
                        # Actions that depend on state
                        stateful_actions = model_actions[model].merge(generic_actions).merge(transitional_actions)

                        # All actions
                        all_actions = stateless_actions.merge(stateful_actions)

                        boolean :manage, "manage #{model}s (overrides all other #{model} permissions)"
                        boolean :create, "create #{model}s"
                        boolean [:alert, :escalated], "be alerted by escalated #{model}s (for higher staff)"

                        # <model>.<action>
                        all_actions.each do |id, verb|
                            if id == :escalate
                                branch id do
                                    involvable :immediately, "escalate #{model}s immediately"
                                    involvable :delayed, "escalate #{model}s after a waiting period"
                                end
                            else
                                involvable id, "#{verb} #{model}s"
                            end
                        end

                        # <model>.action_on_<state>.<action>
                        states.each do |state, transition|
                            branch "action_on_#{state}" do
                                # Generate the perm unless the action transitions into the state
                                stateful_actions.without(transition).each do |id, verb|
                                    involvable id, "#{verb} #{state} #{model}s"
                                end
                            end
                        end

                        # Extra appeal perms that are not stateful
                        if model == :appeal
                            involvable [:sort, :punisher], "sort appeals by punisher"
                            involvable :view_ip, "view IP addresses in appeals"
                        end
                    end # domain block
                end # model loop
            end # begin block

            domain :map do
                branch :phase do
                    Map::Phase.values.each do |phase|
                        phase = phase.name.downcase
                        branch phase do
                            ownable :view, "view #{phase} phase maps"
                        end
                    end
                end

                branch [:rating, :view] do
                    ownable :public, "view public map ratings"
                    ownable :private, "view private map ratings"
                end

                ownable :download, "download maps"
            end

            domain :generic_forum do
                boolean :admin, "access the forums admin area"
                boolean :manage, "manage the forum (overrides all other permissions for this forum)"
                boolean :bypass_cooldown, "bypass the cooldown time for creating forum items"

                branch :topic do
                    boolean :create, "create topics"

                    ownable :reply, "reply to topics"
                    ownable :edit_title, "edit topic titles"
                    ownable :move, "move topics (requires create permissions in new forum)"
                    ownable :approve, "un-hide topics"

                    [:lock, :unlock, :delete, :hide, :pin, :unpin].each do |verb|
                        ownable verb, "#{verb} topics"
                    end

                    [:locked, :hidden, :archived].each do |state|
                        ownable "modify_#{state}", "modify #{state} topics"
                    end

                    {index: "list", view: "view"}.each do |id, verb|
                        ownable "#{id}_parent", "#{verb} topics"
                        ownable [id, :status, :locked], "#{verb} locked topics"
                        ownable [id, :status, :hidden], "#{verb} hidden topics"
                    end
                end

                branch :post do
                    [:view, :edit, :quote].each do |action|
                        ownable "#{action}_parent", "#{action} posts"
                        ownable [action, :status, :hidden], "#{action} hidden posts"
                    end
                    ownable :delete_parent, "delete posts"
                    ownable [:delete, :type, :root], "delete root (original) posts, causing deletion of the topic"
                    ownable :hide, "hide posts"
                    ownable :approve, "un-hide posts"
                    ownable :pin, "pin and unpin posts"
                end
            end

            domain :generic_group do
                boolean :admin, "access the groups admin area"
                boolean :manage, "manage the group (overrides all other permissions for this group)"
                boolean :delete, "delete the group"
                boolean [:edit, :members], "edit group memberships"
            end

            domain :match do
                boolean :validate, "validate/invalidate matches"
            end

            domain :session do
                boolean :admin, "access the sessions admin area"
            end

            domain :trophy do
                boolean :admin, "access the trophy admin area"
            end

            domain :misc do
                branch :player do
                    boolean :view_display_server, "show a player's server even if it's private"
                    boolean :view_suspended, "view suspended players"
                    boolean :view_posts, "filter posts by user"
                    boolean :view_topics, "filter topics by user"
                    boolean :view_new_players, "view the new players list"
                end

                ownable [:alt, :index], "list alts"
                ownable [:name_change, :index], "list username changes"

                boolean [:peek, :view], "view the Peek bar"
                boolean [:cache, :clear], "clear user's cache (removed)"
                boolean [:ipban, :edit], "edit IP bans"
            end
        end
    end
end
