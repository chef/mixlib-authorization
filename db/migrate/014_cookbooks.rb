require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do
    blob_column_type = defined?(Sequel::Postgres) ? "bytea" : "mediumblob"

    create_table(:cookbooks) do
      primary_key :id
      String(:org_id, :null => false, :index => true, :fixed => true, :size => 32)
      String(:name, :null => false) # index is handled with unique index on org/name combo
      String(:authz_id, :null => false, :fixed => true, :size => 32, :unique => true)

      unique([:org_id, :name]) # only one cookbook with a given name in an org
    end

    create_table(:cookbook_versions) do
      String(:id, :primary_key => true, :fixed => true, :size => 32)
      Fixnum(:major, :null => false)
      Fixnum(:minor, :null => false)
      Fixnum(:patch, :null => false)
      Boolean(:frozen, :null => false)

      column :meta_attributes, blob_column_type, :null => false
      String(:meta_deps, :null => false)
      column :meta_long_desc, blob_column_type, :null => false
      column :metadata, blob_column_type, :null => false
      column :serialized_object, blob_column_type, :null => false

      DateTime(:updated_at, :null => false)
      DateTime(:created_at, :null => false)
      String(:last_updated_by, :null => false, :fixed => true, :size => 32)

      foreign_key(:cookbook_id, :cookbooks, :on_delete => :restrict)
      unique([:cookbook_id, :major, :minor, :patch]) # only one cookbook with a given version in an org
    end

    if defined?(Sequel::Postgres)
      # is there a better way to achieve this in Sequel?
      # For Postgresql, the default storage strategy compresses
      # data. Since we intend to store gzip data here, we set the type
      # to EXTERNAL to avoid compression.
      run("ALTER TABLE cookbook_versions ALTER meta_attributes SET STORAGE EXTERNAL")
      run("ALTER TABLE cookbook_versions ALTER meta_long_desc SET STORAGE EXTERNAL")
      run("ALTER TABLE cookbook_versions ALTER metadata SET STORAGE EXTERNAL")
      run("ALTER TABLE cookbook_versions ALTER serialized_object SET STORAGE EXTERNAL")
    end

    create_table(:cookbook_version_checksums) do
      String(:cookbook_version_id, :null => :false, :fixed => true, :size => 32)
      String(:org_id, :null => false, :fixed => true, :size => 32)
      String(:checksum, :null => false, :fixed => true, :size => 32)

      foreign_key([:cookbook_version_id], :cookbook_versions, :key => :id)
      foreign_key([:org_id, :checksum], :checksums, :key => [:org_id, :checksum], :on_delete => :cascade, :on_update => :cascade)
    end

  end
end
