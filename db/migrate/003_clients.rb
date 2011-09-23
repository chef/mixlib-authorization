require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do

    create_table(:clients) do
      String(:id, :primary_key => true, :fixed => true, :size => 32)
      String(:org_id, :null => false, :index => true, :fixed => true, :size => 32)
      String(:authz_id, :null => false, :unique => true, :fixed => true, :size => 32)
      String(:name, :null => false) # Index comes from unique constraint

      tinyint(:pubkey_version, :null => false)
      text(:public_key)

      TrueClass(:validator, :null => false)

      String(:last_updated_by, :null => false, :fixed => true, :size => 32)

      DateTime(:created_at, :null => false)
      DateTime(:updated_at, :null => false)

      unique([:org_id, :name],:name => :org_id_name_unique) # org+name is unique and indexed

      # Notice: before deleting a validator client, we count the number of
      # validators in the org. It seems like this query would benefit from an
      # index on [:org_id, :validator], but I could not get the query planner
      # to use such an index in my tests.
      # index([:org_id, :validator], :name => :org_id_validator)
    end

  end
end

