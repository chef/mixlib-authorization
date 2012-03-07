require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do

    create_table(:databags) do
      String(:id, :primary_key => true, :fixed => true, :size => 32)
      String(:authz_id, :null => false, :fixed => true, :size => 32, :unique => true)
      String(:org_id, :null => false, :index => true, :fixed => true, :size => 32)
      String(:name, :null => false) # index is handled with unique index on org/name combo

      String(:last_updated_by, :null => false, :fixed => true, :size => 32)
      DateTime(:created_at, :null => false)
      DateTime(:updated_at, :null => false)

      unique([:org_id, :name]) # only one databag with a given name in an org
    end
  end
end
