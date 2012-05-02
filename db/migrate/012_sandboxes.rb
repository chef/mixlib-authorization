require File.expand_path('../settings', __FILE__)

Sequel.migration do
  up do
    create_table(:checksums) do
      String(:org_id, :null => false, :fixed => true, :size => 32)
      String(:checksum, :null => false, :fixed => true, :size => 32)
      primary_key [:org_id, :checksum]
    end

    create_table(:sandbox_checksum) do
      String(:org_id, :fixed => true, :size => 32)
      String(:sandbox_id, :fixed => true, :size => 32)
      String(:checksum, :fixed => true, :size => 32)
      DateTime(:created_at, :null => false)
      primary_key [:sandbox_id, :org_id, :checksum]
    end
  end

  down do
    [:sandbox_checksum, :checksums].each do |table|
      drop_table(table)
    end
  end
end
