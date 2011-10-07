module Mixlib
  module Authorization

    # More verbose debugging that could be performance impacting (e.g., extra
    # calls to authz)
    EPIC_DEBUG = false

    DEFAULT_GROUPS =  ["users","clients","admins", "billing-admins"].freeze
    CONTAINERS = [ "clients", "groups", "cookbooks", "data", "containers",
                   "nodes", "roles", "sandboxes", "environments"]

    #==ActorDouble
    # A duck type for any model class where you only have and need the
    # authz_id. Used to make a requesting_actor_id look like a user/client
    # object when updating groups.
    class ActorDouble < Struct.new(:authz_id)
    end

    module Logging
      def debug(msg)
        STDERR.puts "** ORG AUTHZ POLICY: #{msg}"
      end
    end

    #==OrgAuthPolicy
    # OrgAuthPolicy is an abstraction layer/DSL for defining and applying the
    # default authz settings for orgs. The best documentation for using the DSL
    # is the default policy definition (see default_organization_policy.rb).
    #
    # OrgAuthPolicy provides the top level of the DSL. Currently everyone gets
    # the same policy, so only one policy, the default, is supported. Default
    # policy is defined by passing a block to `OrgAuthPolicy.default`
    #
    # OrgAuthPolicy also provides local caching of objects to avoid unneeded
    # database requests via the OrgObjects class.
    class OrgAuthPolicy
      include Logging

      #==OrgObjects
      # Access and caching layer for Container, Group, and Organization objects
      class OrgObjects

        attr_reader :org_db
        attr_reader :requesting_actor_id

        def initialize(org, org_db, user_mapper, scoped_groups, requesting_actor_id)
          @org = org
          @org_db = org_db
          @requesting_actor_id = requesting_actor_id
          @scoped_groups = Mixlib::Authorization::Models::ScopedGroup.new(@org_db, @org_db, @user_mapper, nil, nil)

          @groups_by_name = {}
          @containers_by_name = {}
        end

        def container(container_name)
          @containers_by_name[container_name] ||= begin
            Mixlib::Authorization::Models::Container.on(org_db).by_containername(:key => container_name).first
          end
        end

        def group(group_name)
          @groups_by_name[group_name] ||= @scoped_groups.find_by_name(group_name)
        end

        def organization
          @org
        end
      end

      #==AclPolicy
      # Updates the ACEs of containers, groups, or the org itself to contain
      # the specified group.
      class AclPolicy
        include Logging

        attr_reader :ace_types
        attr_reader :group_name
        attr_reader :org_objects

        def initialize(ace_types, group_name, org_objects)
          if EPIC_DEBUG
            debug("Initializing ACL POLICY ENGINE")
            debug("     group_name: #{group_name}")
            debug("      ace_types: #{ace_types.inspect}")
            debug("    org_objects: #{org_objects.inspect}")
          end
          @ace_types = ace_types
          @org_objects = org_objects
          @group_name = group_name
        end

        ######################################################################
        # DSL API
        ######################################################################

        # Apply the acl policy to the specified containers
        def containers(*containers)
          containers.each do |container_name|
            grant_rights_on_container(container_name.to_s)
          end
        end

        # Apply the acl policy to all containers. Basically just DSL sugar for
        # giving the admins group rights to everything.
        def all_containers
          CONTAINERS.each do |container_name|
            grant_rights_on_container(container_name.to_s)
          end
        end

        # Apply the acl policy to the specified +target_groups+
        def groups(*target_groups)
          target_groups.each do |target_group_name|
            grant_rights_on_group(target_group_name)
          end
        end

        # Apply the acl policy to the organization itself. Used to give R/W
        # access to the admins group, for example.
        def organization
          org = org_objects.organization
          group = org_objects.group(group_name)
          org_acl = Acl.new(org.fetch_join_acl)
          org_acl.each_ace(*ace_types) do |ace_name, ace|
            ace.add_group(group.authz_id)
            org.update_join_ace(ace_name, ace.to_hash)
          end
        end

        alias :group :groups

        ######################################################################
        # INTERNAL API
        ######################################################################

        def grant_rights_on_container(container_name)
          debug("  * Granting [#{ace_types.join(', ')}] on #{container_name} container to #{group_name} group")

          group = org_objects.group(group_name)
          container = org_objects.container(container_name)
          container_acl = Acl.new(container.fetch_join_acl)
          container_acl.each_ace(*ace_types) do |ace_name, ace|
            ace.add_group(group.authz_id)
            container.update_join_ace(ace_name, ace.to_hash)
          end
          debug("  * Resulting container ACL: #{group.fetch_join_acl.inspect}") if EPIC_DEBUG
        end

        def grant_rights_on_group(target_group_name)
          debug("  * Granting [#{ace_types.join(', ')}] on #{target_group_name} group to #{group_name} group")
          target_group = org_objects.group(target_group_name)
          group = org_objects.group(group_name)
          target_group_acl = Acl.new(target_group.fetch_join_acl)
          target_group_acl.each_ace(*ace_types) do |ace_name, ace|
            ace.add_group(group.authz_id)
            target_group.update_join_ace(ace_name, ace.to_hash)
          end
          debug("  * Resulting group ACL: #{group.fetch_join_acl.inspect}") if EPIC_DEBUG
        end
      end

      #==GroupAuthPolicy
      # Provides a means to manipulate groups, and creates AclPolicy objects to
      # add groups to objects' ACEs.
      class GroupAuthPolicy
        include Logging

        attr_reader :group_name
        attr_reader :org_objects

        def initialize(group_name, org_objects)
          @group_name = group_name
          @org_objects = org_objects
        end

        # Adds the requesting_actor (assumed to be the superuser, aka pivotal) to the group.
        def includes_superuser
          debug("* Adding superuser to #{group_name} group")
          group = org_objects.group(group_name)
          group.add_actor(ActorDouble.new(org_objects.requesting_actor_id))
        end

        # Define ACL policy for this group via a block. Any
        # containers/groups/etc. referenced in the block with have this group
        # added to the ACEs specified in the +ace_types+
        def have_rights(*ace_types) # yields acl_policy
          debug("* Adding #{group_name} group to ACEs:")
          acl_policy = AclPolicy.new(ace_types, group_name, org_objects)
          yield acl_policy
        end

        # Removes *all* groups from the specified aces. Used to make highly
        # restricted groups. In current use, only the billing-admins group
        # requires this.
        def clear_groups_from(*ace_types)
          debug("* Clearing ACEs #{ace_types.join(', ')} on #{group_name} group")
          group = org_objects.group(group_name)
          group_acl = Acl.new(group.fetch_join_acl)
          group_acl.each_ace(*ace_types) do |ace_name, ace|
            ace.groups.clear
            group.update_join_ace(ace_name, ace.to_hash)
          end
        end
      end

      attr_reader :org_name
      attr_reader :org_db
      attr_reader :requesting_actor_id
      attr_reader :user_mapper
      attr_reader :org_objects

      # Define the default policy via a block
      def self.default(&default_policy)
        @default_policy = default_policy
      end

      def self.default_policy
        @default_policy
      end

      def initialize(org, org_db, user_mapper, requesting_actor_id)
        debug("Initializing Policy Engine:")
        debug("     ORG NAME: #{org.name}")
        debug("       ORG DB: #{org_db}")
        debug("  user_mapper: #{user_mapper}")
        debug("          RAD: #{requesting_actor_id}")

        @org = org
        @org_name = org.name
        @org_db = org_db
        @global_db = Mixlib::Authorization::Config.default_database
        @requesting_actor_id = requesting_actor_id
        @scoped_groups = Mixlib::Authorization::Models::ScopedGroup.new(@org_db, @org_db, user_mapper, nil, nil)
        @global_groups = Mixlib::Authorization::Models::ScopedGroup.new(@global_db, @org_db, user_mapper, nil, nil)
        @org_objects = OrgObjects.new(org, org_db, user_mapper, @scoped_groups, requesting_actor_id)
      end

      # Evaluates the default policy in the context of the organization
      # specified in the constructor. IOW, run the damn thing.
      def apply!
        instance_eval(&self.class.default_policy)
      end

      ######################################################################
      # DSL API
      ######################################################################

      # Create the given containers
      def has_containers(*containers)
        containers.each do |container_name|
        debug("* Creating #{container_name} container")
          Models::Container.on(org_db).new( :containername => container_name,
                                            :containerpath => container_name,
                                            :requester_id  => requesting_actor_id).save
        end
      end

      # Create the given +groups+
      def has_groups(*groups)
        groups.each do |group_name|
          debug("* Creating #{group_name} group")
          @scoped_groups.new( :orgname                => org_name,
                              :groupname              => group_name,
                              :actor_and_group_names  => {},
                              :requester_id           => requesting_actor_id).save
        end
      end

      # Create a global admins group
      def has_global_admins_group
        debug("* Creating global admins group")
        @global_groups.new(:groupname=> "#{org_name}_global_admins",
                           :orgname => org_name,
                           :actor_and_group_names=> { "groups" => ["admins"] },
                           :requester_id=>requesting_actor_id).save
      end

      # Define a GroupAuthPolicy for the group +name+ via a block.
      def group(name)
        group_policy = GroupAuthPolicy.new(name, @org_objects)
        yield group_policy
      end

      # just yields the block, to make it explicit what's going on.
      def create_default_objects
        yield
      end
    end
  end
end
