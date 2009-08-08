#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

class Mixlib::Authorization::Models::Group < CouchRest::ExtendedDocument
  include CouchRest::Validation
  include Mixlib::Authorization::AuthHelper
  include Mixlib::Authorization::JoinHelper

  unique_id :gen_guid
  
  view_by :groupname

  property :groupname
  property :requester_id

  validates_present :groupname

  validates_format :groupname, :with => /^[a-z0-9\-_]+$/
  
  auto_validate!

  save_callback :after, :transform_and_create
  destroy_callback :before, :delete_join


  def transform_and_create
    self["actors"], self["groups"] = transform_names_to_auth_ids(database,self["actor_and_group_names"])
    create_join
  end

  join_type OpscodeAccount::JoinTypes::Group

  join_properties :groupname, :actors, :groups, :requester_id
  
  def for_json
    actors_and_groups_auth = fetch_join
    actors_and_groups = {
      "actors" => transform_actor_ids(actors_and_groups_auth["actors"], database, :to_user),
      "groups" => transform_group_ids(actors_and_groups_auth["groups"], database, :to_user)}
    Mixlib::Authorization::Log.debug("join_data: #{actors_and_groups.inspect}")
    properties.inject({ }) do |result, prop|
      { :groupname => groupname }.merge(actors_and_groups)
    end
  end
end  

