require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do

    create_table(:node_statuses) do
      String(:id, :primary_key => true, :fixed => true, :size => 32)
      String(:node_name, :null => false, :unique => true)
      Integer(:status, :null => false)

      # String(:last_updated_by, :null => false, :fixed => true, :size => 32)
      # DateTime(:created_at, :null => false)
      # DateTime(:updated_at, :null => false)
    end
  end
end
