require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do

    create_table(:data_bag_items) do
      String(:id, :primary_key => true, :fixed => true, :size => 32)
      # We deliberately left out authz_id, but we will add it in the future when data_bag_items 
      # have their own ACLs

      # We considered merging :org_id and :data_bag_name into a single
      # field using the guid of the data_bag, but decided against
      # because that would lock us into making two lookups to find a
      # data_bag item.
      # index is handled with unique index on org/data_bag_name/item_name combo
      String(:org_id, :null => false, :index => true, :fixed => true, :size => 32)
      String(:data_bag_name, :null => false)
      String(:item_name, :null => false)

      String(:last_updated_by, :null => false, :fixed => true, :size => 32)
      DateTime(:created_at, :null => false)
      DateTime(:updated_at, :null => false)

      if defined?(Sequel::MySQL)
        mediumblob(:serialized_object)
      elsif defined?(Sequel::Postgres)
        bytea(:serialized_object)
      else
        raise "Unsupported database"
      end

      # only one data_bag_item with a given data_bag name / item_name in
      # an org. Mysql and pgsql both allow lookups on indices with
      # partial prefixes; in other words we get the benefit of the index if we
      # are looking up org_id/data_bag_name, as we will when we list
      # all the items in a data_bag. (see postgres docs section 11.5,
      # "Combining Multiple Indexes") (mysql apparently does the same thing)
      unique([:org_id, :data_bag_name, :item_name]) 
    end
    if defined?(Sequel::Postgres)
      # is there a better way to achieve this in Sequel?
      # For Postgresql, the default storage strategy compresses
      # data. Since we intend to store gzip data here, we set the type
      # to EXTERNAL to avoid compression.
      run("ALTER TABLE data_bag_items ALTER serialized_object SET STORAGE EXTERNAL")
    end
  end
end
