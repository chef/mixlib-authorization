require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do
    # Add column for Open Source users into users table
    # This is so same schema can be used for private and open source
    # chef
    # Admin column is not used by Private Chef and is ignored there
    #
    # In addition, the open id field is going to use the
    # external_authentication_uid field, since it already exists
    # in private chef for a different purpose and can be repurposed
    # for open source chef to hold open id
    #
    # Open source password + salt will be stored in the
    # serialized_object field
    #
    # Dummy values will fill in private chef fields that cannot
    # be null but are not needed by open source chef
    alter_table(:users) do
      add_column :admin, TrueClass, :null => false, :default => false
    end

    # Same reasoning as above, except on clients table
    alter_table(:clients) do
      add_column :admin, TrueClass, :null => false, :default => false
    end
  end
end
