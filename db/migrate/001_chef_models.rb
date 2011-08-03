Sequel.migration do
  change do

    create_table(:users) do
      String(:id, :primary_key => true, :fixed => true, :size => 32)
      String(:authz_id, :null => false, :fixed => true, :size => 32, :unique => true)
      String(:username, :null => false, :unique => true)
      String(:email, :null => false, :unique => true)
      Fixnum(:pubkey_version, :null => false)
      # These should be 1176 chars exactly AFAICT, it may be possible to optimize.
      text(:public_key)

      blob(:serialized_object)

      String(:last_updated_by, :null => false, :fixed => true, :size => 32)
      DateTime(:created_at, :null => false)
      DateTime(:updated_at, :null => false)
    end

  end
end
