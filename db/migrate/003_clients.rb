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

      unique([:org_id, :name]) # org+name is unique and indexed
    end

  end
end

