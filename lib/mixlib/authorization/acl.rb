#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

module Mixlib
  module Authorization

    class Acl
      include Mixlib::Authorization::AuthHelper
      
      ACES = ["create","read","update","delete","grant"]
      attr_reader :aces
      
      def initialize(aces_in=nil)
        @aces = if aces_in.nil?
                  ACES.inject({ }) { |memo, ace_name| memo[ace_name]=Ace.new; memo}
                else
                  if aces_in.respond_to?(:keys)
                    aces_in.inject({ }) { |memo, ace_tuple| memo[ace_tuple[0]]= Ace.new(ace_tuple[1]); memo }
                  else
                    aces_in
                  end
                end
      end
      
      def ==(other)
        other.respond_to?(:for_json) && other.for_json == for_json
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

      def to_user(org_database)
        Acl.new(@aces.inject({ }) { |memo, ace_tuple| memo[ace_tuple[0]] = ace_tuple[1].to_user(org_database).for_json; memo })
      end
      
      def to_auth(org_database)
        Acl.new(@aces.inject({ }) { |memo, ace_tuple| memo[ace_tuple[0]] = ace_tuple[1].to_auth(org_database).for_json; memo })
      end
      
      def for_json
        @aces.inject({ }) { |memo, ace_tuple| memo[ace_tuple[0]] = ace_tuple[1].for_json; memo}
      end

      def merge!(other_acl)
        ACES.each do |ace_name|
          @aces[ace_name].merge!(other_acl.aces[ace_name])
        end
      end
    end
    
    class Ace
      include Mixlib::Authorization::AuthHelper

      attr_reader :ace
      
      def initialize(ace_data=nil)
        @ace = ace_data || { "actors"=>[], "groups"=>[] }
      end
      
      def actors
        ace["actors"]
      end
      
      def groups
        ace["groups"]
      end

      def add_actor(member)
        @ace["actors"] << member
        self
      end
      
      def add_group(member)
        @ace["groups"] << member
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

      def to_auth(org_database)
        Ace.new({ "actors" => transform_actor_ids(ace["actors"], org_database, :to_auth),
                  "groups"=>transform_group_ids(ace["groups"], org_database, :to_auth)} )
      end

      def to_user(org_database)
        Ace.new({ "actors" => transform_actor_ids(ace["actors"], org_database, :to_user),
                  "groups"=>transform_group_ids(ace["groups"], org_database, :to_user)} )
      end

      def for_json
        @ace
      end

      def merge!(other_ace)
        @ace["actors"].concat(other_ace.actors).uniq!
        @ace["groups"].concat(other_ace.groups).uniq!
      end
      
      def ==(other)
        other.respond_to?(:ace) && other.ace == ace
      end
    end

    class AuthAcl < Acl
      def self.from_acl_data(acl_data)
        AuthAcl.new(ACES.inject({ }) { |memo,ace_name| memo[ace_name] = Ace.new(self, acl_data[ace_name]); memo })
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
