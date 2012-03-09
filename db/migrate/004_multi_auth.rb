require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do

    create_table(:external_authn) do
      primary_key(:id)
      String(:user_id, :fixed => true, :size => 32)
      String(:external_user_id, :null => false, :unique => true)

      # this probably needs a lookup table...how normalized shall we be?
      enum :provider, :elements => ['ldap']

      # A hash of all external information gathered about a user in the format it was gathered.
      # text(:external_serialized_object)

      String(:last_updated_by, :null => false, :fixed => true, :size => 32)
      DateTime(:created_at, :null => false)
      DateTime(:updated_at, :null => false)

      foreign_key([:user_id], :users, :key => :id)
      unique [:external_user_id, :provider]
    end

    alter_table(:users) do
      add_column :recovery_authn_enabled, TrueClass, :null => false
    end

  end
end
