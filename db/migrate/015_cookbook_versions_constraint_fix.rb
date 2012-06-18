require File.expand_path('../settings', __FILE__)

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
