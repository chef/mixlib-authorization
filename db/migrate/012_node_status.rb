require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do
    alter_table(:nodes) do
      add_column :status, Integer, :null => true
    end
  end
end
