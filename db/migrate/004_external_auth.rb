require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do
    alter_table(:users) do
      # this probably needs a lookup table...how normalized shall we be?
      add_column :external_authn_provider, String, :null => true, :size => 5
      add_column :external_authn_uid, String, :null => true
      add_column :recovery_authn_enabled, TrueClass, :null => true
    end

  end
end
