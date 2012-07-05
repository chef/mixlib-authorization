require File.expand_path('../settings', __FILE__)

platform = if defined?(Sequel::Postgres)
             :postgres
           elsif defined?(Sequel::MySQL)
             :mysql
           end

Sequel.migration do
  up do

    # This is the same view that was introduced in the
    # `016_latest_cookbooks` migration, with the addition of a
    # `version` column.  I decided to pull this concatenation logic up
    # into the view itself, as more than one prepared statement now
    # needs it.
    #
    # Equivalent functionality will be provided in MySQL by a normal
    # query... see notes in the mysql_statements.config file of Erchef
    # for more details.
    case platform
    when :postgres
      # Need to drop the view before replacing it because we're adding a field
      execute "DROP VIEW cookbook_versions_by_rank;"
      execute <<EOM
CREATE OR REPLACE VIEW cookbook_versions_by_rank(
    -- Cookbook Version fields
    major, -- these 3 are needed for version information (duh)
    minor,
    patch,
    version, -- concatenated string of the complete version
    serialized_object, -- needed to access recipe manifest

    -- Cookbook fields
    org_id, -- used for filtering
    name, -- both version and recipe queries require the cookbook name

    -- View-specific fields
    -- (also used for filtering)
    rank) AS
SELECT v.major,
       v.minor,
       v.patch,
       v.major || '.' || v.minor || '.' || v.patch,
       v.serialized_object,
       c.org_id,
       c.name,
       rank() OVER (PARTITION BY v.cookbook_id
                    ORDER BY v.major DESC, v.minor DESC, v.patch DESC)
FROM cookbooks AS c
JOIN cookbook_versions AS v
  ON c.id = v.cookbook_id;
EOM
    end
  end # End up block

  down do
    case platform
    when :postgres
      # Hmm... we can't really drop the view here... gotta
      # recapitulate the original view definition :(
      #
      # NOTE: If we ever need to do this again, we should look into
      # storing these definitions externally (to the migration file)
      # somehow so we only need to have them in one place
      #
      # THIS IS THE VIEW AS IT EXISTED BEFORE THIS MIGRATION
      execute "DROP VIEW cookbook_versions_by_rank;"
      execute <<EOM
CREATE OR REPLACE VIEW cookbook_versions_by_rank(
    -- Cookbook Version fields
    major, -- these 3 are needed for version information (duh)
    minor,
    patch,
    serialized_object, -- needed to access recipe manifest

    -- Cookbook fields
    org_id, -- used for filtering
    name, -- both version and recipe queries require the cookbook name

    -- View-specific fields
    -- (also used for filtering)
    rank) AS
SELECT v.major,
       v.minor,
       v.patch,
       v.serialized_object,
       c.org_id,
       c.name,
       rank() OVER (PARTITION BY v.cookbook_id
                    ORDER BY v.major DESC, v.minor DESC, v.patch DESC)
FROM cookbooks AS c
JOIN cookbook_versions AS v
  ON c.id = v.cookbook_id;
EOM
    end
  end
end
