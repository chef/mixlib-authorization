require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do

    create_table(:nodes) do
      String(:id, :primary_key => true, :fixed => true, :size => 32)
      String(:authz_id, :null => false, :fixed => true, :size => 32, :unique => true)
      String(:org_id, :null => false, :index => true, :fixed => true, :size => 32)
      String(:name, :null => false) # index is handled with unique index on org/name combo
      String(:environment, :null => false)
      mediumblob(:serialized_object)
      String(:last_updated_by, :null => false, :fixed => true, :size => 32)
      DateTime(:created_at, :null => false)
      DateTime(:updated_at, :null => false)

      unique([:org_id, :name]) # only one node with a given name in an org
      index([:org_id, :environment]) # List all the nodes in an environment
    end

  end
end
