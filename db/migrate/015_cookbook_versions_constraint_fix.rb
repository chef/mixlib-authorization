require File.expand_path('../settings', __FILE__)

# Add NOT NULL constraints to some cookbook tables

# These columns are part of foreign key constraints,
# and really should never be NULL.  What is a cookbook_version
# without a cookbook?  What is a cookbook_version_checksum
# without a cookbook_version?

Sequel.migration do
  up do
    alter_table :cookbook_versions do
      set_column_allow_null(:cookbook_id, false)
    end
    alter_table :cookbook_version_checksums do
      set_column_allow_null(:cookbook_version_id, false)
    end
  end

  down do
    alter_table :cookbook_versions do
      set_column_allow_null(:cookbook_id, true)
    end
    alter_table :cookbook_version_checksums do
      set_column_allow_null(:cookbook_version_id, false)
    end
  end

end
