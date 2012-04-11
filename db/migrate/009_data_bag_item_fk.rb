require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do
    alter_table(:data_bag_items) do
      add_foreign_key [:org_id, :data_bag_name], :data_bags, :key => [:org_id, :name], :on_delete => :cascade, :on_update => :cascade
    end
  end
end
