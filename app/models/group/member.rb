class Group
    # Base for models that can be members of groups
    module Member
        extend ActiveSupport::Concern
        include Mongoid::Document
        include Permissions::AggregateHolder

        included do
            embeds_many :memberships, class_name: Membership.name

            field :admin, type: Boolean, default: false

            # Users with an embedded Membership matching the given criteria e.g.
            #
            #    User.with_membership(:group => some_group, $stop => {$gt => Time.now})
            #
            # Note that this uses $elemMatch in the query, meaning that a placeholder
            # for the matching Membership will be available for updates as 'memberships.$'
            scope :with_membership, -> (criterion) {
                self.where(memberships: {$elemMatch => criterion})
            }

            # Users without any embedded Membership matching the given criteria
            scope :without_membership, -> (criterion) {
                self.where(memberships: {$not => {$elemMatch => criterion}})
            }

            # Users who are members of the given group right now
            scope :in_group, -> (group, at: Time.now) {
                sel = {group_id: group.id}
                at and sel.merge!(:start.lte => at, :stop.gt => at)
                with_membership(sel)
            }

            scope :in_any_group, -> (*groups, at: Time.now) {
                sel = {:group_id.in => groups.map(&:id)}
                at and sel.merge!(:start.lte => at, :stop.gt => at)
                with_membership(sel)
            }

            # Users who are members of the given group at all times
            scope :permanently_in_group, -> (group) {
                with_membership :group_id => group.id, :start => Time::INF_PAST, :stop => Time::INF_FUTURE
            }

            index({admin: 1})
            index({'memberships.group_id' => 1})
            index({'memberships.start' => 1})
            index({'memberships.stop' => 1})
        end # included do

        module ClassMethods
            def permission_groups
                [Group.default_group]
            end

            def admins
                where(admin: true)
            end

            def with_permission(*permission)
                # We need to test each member individually for the perm,
                # because a higher priority group could override it.
                [*admins, *in_any_group(*Group.with_permission(*permission)).select{|member| member.has_permission?(*permission) }]
            end
        end

        def instance_admin?
            self[:admin]
        end

        def active_memberships
            self.memberships.select(&:active?).sort_by{|m| m.group.priority }
        end

        def membership_in(group)
            self.memberships.find_by(group: group)
        end

        def active_groups
            active_memberships.map(&:group)
        end
        alias_method :instance_permission_groups, :active_groups

        def primary_group
            self.active_groups.first || Group.default_group
        end

        # Tests if this user is in the given group using the current loaded state.
        # If the user joins the group through a different instance, you will have
        # to call reload on this instance to make it reflect the persisted change.
        def in_group?(group, active=true)
            self.memberships.any? {|m| m.group_id == group._id && (!active || m.active?)}
        end

        # Create a Membership for this user in the given Group, replacing any
        # existing Membership for that group. The results are written directly to the
        # database and this User document is then reloaded. Any unsaved changes to the
        # document will be lost.
        def join_group(group, start: nil, stop: nil, staff_role: nil, reload: true)
            membership = Membership.new(group: group,
                                        start: start || Time.now,
                                        stop: stop || Time::INF_FUTURE,
                                        staff_role: staff_role)
            membership.validate!

            # We use two queries to effectively upsert an embedded document in a safe way.
            # The first query tries to find an existing membership for the given group and update it.
            # The second query creates a membership only if one does NOT already exist for the given group.
            # Generally, only one of these queries will write anything, except in the unlikely case where
            # a membership updated by the first query is concurrently deleted before the second query runs.
            # In that case, the second query will just recreate the membership, which is a valid result.

            self.where_self.with_membership(group_id: group.id).set('memberships.$' => membership.as_document)
            self.where_self.without_membership(group_id: group.id).push(memberships: membership.as_document)

            self.reload if reload

            self
        end

        # Destroy any Membership this user has for the given Group. The results
        # are written directly to the database and this User document is then reloaded.
        # Any unsaved changes to the document will be lost.
        def leave_group(group, expire: false)
            if expire
                update_membership(group, {stop: Time.now})
            else
                self.where_self.pull(memberships: {group_id: group._id})
            end
            self.reload
            self
        end

        # Update this user's User::Membership subdocument for the given group, if it exists.
        # The update is performed atomically, directly on the database. The changes parameter
        # is passed to the $set operator, but the field names should be relative to the
        # Membership, not the User.
        def update_membership(group, changes)
            self.where_self
                .with_membership(group_id: group.id)
                .set(changes.mash {|k, v| ["memberships.$.#{k}", v] })
        end
    end # Member
 end
