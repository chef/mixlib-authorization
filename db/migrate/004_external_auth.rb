require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do
    alter_table(:users) do
      add_column :external_authentication_uid, String, :null => true
      add_column :recovery_authentication_enabled, TrueClass, :null => true
    end

  end
end
