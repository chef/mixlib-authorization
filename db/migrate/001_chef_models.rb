Sequel.migration do
  change do

    # rw_attribute :id
    # rw_attribute :authz_id
    # rw_attribute :first_name
    # rw_attribute :last_name
    # rw_attribute :middle_name
    # rw_attribute :display_name
    # rw_attribute :email
    # rw_attribute :username
    # rw_attribute :public_key
    # rw_attribute :certificate

    # ro_attribute :password # with a custom setter below
    # ro_attribute :hashed_password
    # ro_attribute :salt

    create_table(:users) do
      String(:id, :primary_key => true, :fixed => true, :size => 32)
      String(:authz_id, :null => false, :index => true, :fixed => true, :size => 32)
      String(:username, :null => false, :index => true)
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
