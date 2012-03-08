require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do

    create_table(:environments) do
      String(:id, :primary_key => true, :fixed => true, :size => 32)
      String(:authz_id, :null => false, :fixed => true, :size => 32, :unique => true)
      String(:org_id, :null => false, :index => true, :fixed => true, :size => 32)
      String(:name, :null => false) # index is handled with unique index on org/name combo

      String(:last_updated_by, :null => false, :fixed => true, :size => 32)
      DateTime(:created_at, :null => false)
      DateTime(:updated_at, :null => false)

      if defined?(Sequel::MySQL)
        mediumblob(:serialized_object)
      elsif defined?(Sequel::Postgres)
        bytea(:serialized_object)
      else
        raise "Unsupported database"
      end

      unique([:org_id, :name]) # only one node with a given name in an org
    end
    if defined?(Sequel::Postgres)
      # is there a better way to achieve this in Sequel?
      # For Postgresql, the default storage strategy compresses
      # data. Since we intend to store gzip data here, we set the type
      # to EXTERNAL to avoid compression.
      run("ALTER TABLE environments ALTER serialized_object SET STORAGE EXTERNAL")
    end
  end
end
