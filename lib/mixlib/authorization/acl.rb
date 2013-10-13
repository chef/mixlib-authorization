#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'mixlib/authorization/auth_helper'
require 'mixlib/authorization/id_mapping_helper'

module Mixlib
  module Authorization

    class Acl
      include Mixlib::Authorization::AuthHelper
      include Mixlib::Authorization::IDMappingHelper


      ACES = ["create","read","update","delete","grant"]
      attr_reader :aces

      # @param aces_in [Hash, ???] Initial state of the ACL
      # @param authz_id_mapper [Mixlib::Authorization::AuthzIDMapper]
      #   mapper responsible for converting between user and client
      #   Authz IDs and names, and vice versa.
      # @todo Do we ever pass a non-Hash into this?  If so, what is
      #   the type?  It looks like it'd always be a Hash...
      def initialize(aces, authz_id_mapper=nil)
        @authz_id_mapper = authz_id_mapper
        @aces = if aces.respond_to?(:keys)
                  aces.inject({}) do |memo, ace_tuple|
                    memo[ace_tuple[0]]= Ace.new(ace_tuple[1], @authz_id_mapper)
                    memo
                  end
                else
                  aces
                end
      end

      def ==(other)
        other.respond_to?(:aces) && other.aces == aces
      end

      def each_ace(*aces_to_yield)
        aces_to_yield = ACES if aces_to_yield.empty?
        aces_to_yield.each do |ace|
          ace_name = ace.to_s
          yield [ace_name, @aces[ace_name]]
        end
      end

      def add(ace_name, ace)
        ace_name_string = ace_name.to_s
        if ACES.include?(ace_name_string)
          @aces[ace_name_string] = ace
        end
      end

      def remove(ace_name)
        @aces.delete(ace_name)
      end

      def to_user
        Acl.new(@aces.inject({}) do |memo, ace_tuple|
                  memo[ace_tuple[0]] = ace_tuple[1].to_user.for_json;
                  memo
                end, @authz_id_mapper)
      end

      def to_auth
        Acl.new(@aces.inject({}) do |memo, ace_tuple |
                  memo[ace_tuple[0]] = ace_tuple[1].to_auth.for_json
                  memo
                end,
                @authz_id_mapper)
      end

      def for_json
        @aces.inject({ }) { |memo, ace_tuple| memo[ace_tuple[0]] = ace_tuple[1].for_json; memo}
      end

      alias :to_hash :for_json

      def merge!(other_acl)
        ACES.each do |ace_name|
          @aces[ace_name].merge!(other_acl.aces[ace_name])
        end
      end
    end

    class Ace

      include Mixlib::Authorization::AuthHelper

      # TODO: This looks like it is only used for the following:
      #
      # transform_actor_ids
      # transform_group_ids
      #
      # These just map user and client authz ids => *names* (not user-side IDs), and vice versa
      include Mixlib::Authorization::IDMappingHelper

      attr_reader :ace

      # @param ace [Hash<String, Array>] a hash with `"actors"` and `"groups"` keys
      # @param authz_id_mapper [Mixlib::Authorization::AuthzIDMapper]
      #   mapper responsible for converting between user and client
      #   Authz IDs and names, and vice versa.
      def initialize(ace, authz_id_mapper)
        @ace, @authz_id_mapper = ace, authz_id_mapper
      end

      def actors
        ace["actors"]
      end

      def groups
        ace["groups"]
      end

      def add_actor(member)
        @ace["actors"] << member
        @ace["actors"].sort!
        self
      end

      def add_group(member)
        @ace["groups"] << member
        @ace["groups"].sort!
        self
      end

      def remove_actor(member)
        @ace["actors"].delete(member)
        self
      end

      def remove_group(member)
        @ace["groups"].delete(member)
        self
      end

      # Map an ace containing user-facing names into their Authz ID
      # counterparts.  Assumes the Ace contains names, and does not
      # currently verify this.
      #
      # @return [Ace]
      def to_auth
        actor_ids = @authz_id_mapper.actor_names_to_authz_ids(actors)
        group_ids = @authz_id_mapper.group_names_to_authz_ids(groups)

        # TODO: Don't like that the mapper needs to be passed through...
        Ace.new({"actors" => actor_ids, "groups" => group_ids},
                @authz_id_mapper)
      end

      # Map an ace containing Authz IDs to their user-facing name
      # counterparts.  Assumes the Ace contains Authz IDs, and does
      # not currently verify this.
      #
      # @return [Ace]
      def to_user
        actors = @authz_id_mapper.actor_authz_ids_to_names(@ace["actors"])
        groups = @authz_id_mapper.group_authz_ids_to_names(@ace["groups"])

        # Since the ID mapper returns a hash for the actor IDs we need
        # to flatten first.  Since there's only ever one kind of
        # group, those names are already flattened.
        actor_names = actors[:users] + actors[:clients]

        # TODO: Don't like that the mapper needs to be passed through...
        Ace.new({"actors" => actor_names, "groups" => groups},
                @authz_id_mapper)
      end

      def for_json
        @ace
      end

      alias :to_hash :for_json

      # We want to keep the actor and group aces sorted so that ==
      # works predictably
      def merge!(other_ace)
        @ace["actors"] = @ace["actors"].concat(other_ace.actors).sort.uniq
        @ace["groups"] = @ace["groups"].concat(other_ace.groups).sort.uniq
      end

      # We ensure that the individual aces are sorted before doing the
      # comparison to account for any differences in ordering that may
      # have been introduced in any manipulations that were performed
      # on them.
      def ==(other)
        other.respond_to?(:ace) &&
          other.ace["actors"].sort == ace["actors"].sort &&
          other.ace["groups"].sort == ace["groups"].sort
      end
    end

    class AuthAcl < Acl
      def self.from_acl_data(acl_data, authz_id_mapper)
        AuthAcl.new(ACES.inject({}) do |memo,ace_name |
                      memo[ace_name] = Ace.new(self, acl_data[ace_name], authz_id_mapper)
                      memo
                    end, authz_id_mapper)
      end
    end

    class UserAcl < Acl
      attr_reader :org_name

      def initialize(orgname, acl_data)
        @org_name = orgname
        super(acl_data)
      end

      def org_database
        @org_database ||= database_from_orgname(org_name)
      end

      def to_auth
        AuthAcl.new(aces.collect { |ace| ace.to_auth(org_database) })
      end
    end
  end

end
