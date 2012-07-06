require File.expand_path('../settings', __FILE__)

platform = if defined?(Sequel::Postgres)
             :postgres
           elsif defined?(Sequel::MySQL)
             :mysql
           end

Sequel.migration do
  up do

    # The joined_cookbook_version view is identical on Postgres and
    # MySQL, except for the method used to concatenate the version
    # components.  To prevent copying the entire view definition
    # twice, we'll just extract the concatenation logic here and plug
    # it in .
    concatenation_logic = case platform
                          when :postgres
                            "v.major || '.' || v.minor || '.' || v.patch"
                          when :mysql
                            "CONCAT_WS('.', v.major, v.minor, v.patch)"
                          end

    execute <<EOM
CREATE OR REPLACE VIEW joined_cookbook_version(
    -- Cookbook Version fields
    major, -- these 3 are needed for version information (duh)
    minor,
    patch,
    version, -- concatenated string of the complete version
    serialized_object, -- needed to access recipe manifest
    id, -- used for retrieving environment-filtered recipes

    -- Cookbook fields
    org_id, -- used for filtering
    name) -- both version and recipe queries require the cookbook name
AS
SELECT v.major,
       v.minor,
       v.patch,
       #{concatenation_logic},
       v.serialized_object,
       v.id,
       c.org_id,
       c.name
FROM cookbooks AS c
JOIN cookbook_versions AS v
  ON c.id = v.cookbook_id;
EOM
  end

  down do
    execute "DROP VIEW joined_cookbook_version;"
  end
end
