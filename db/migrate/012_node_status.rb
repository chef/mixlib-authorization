require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do
    alter_table(:nodes) do
      Integer(:status)
    end
  end
end
