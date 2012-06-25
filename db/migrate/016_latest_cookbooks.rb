require File.expand_path('../settings', __FILE__)

platform = if defined?(Sequel::Postgres)
             :postgres
           elsif defined?(Sequel::MySQL)
             :mysql
           end

Sequel.migration do
  up do
    # Alright, kids, we're using specific database features here!
    #
    # Postgres has nice support for window functions, so we're going
    # to use a view there to grab the latest version(s) of cookbooks.
    #
    # MySQL doesn't have this, though, so to keep things clean on the
    # Erchef side, we're going to use stored procedures that do
    # basically the same thing.
    #
    # As a result, we're foregoing the usual Sequel helper functions,
    # since they can't do this stuff anyway.
    case platform
    when :postgres
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

    when :mysql
      execute <<EOM
CREATE PROCEDURE prepare_latest_cookbook_data(IN organization CHAR(32), IN num_latest INTEGER)
BEGIN
    -- This stored procedure ultimately generates a temporary table filled
    -- with the cookbook name, version information, and serialized object for
    -- the `num_latest` most recent versions of all cookbooks in an organization.

    -- This temporary table, named 'latest_cb_versions_temp' is then utilized in
    -- other stored procedures that either return the version information or the
    -- recipe information.  This separation is undesirable, but necessary, because
    -- MySQL stored procedures cannot actually return result sets directly, and
    -- cannot be used as table expressions in queries.

    -- The INSTANT that MySQL ever gets window query support, this stored
    -- procedure and the two that follow it should IMMEDIATELY be replaced
    -- with a view like we have on Postgres

    -- -----------------------------------------------------------------------------

    -- These variables correspond to the columns we select in the cursor, and what
    -- we insert into the temporary table.
    --
    -- Should we decide to change the types of the corresponding columns in the
    -- cookbooks or cookbook_versions table, these declarations and the definition
    -- of the temporary table should be altered as appropriate.
    DECLARE current_cookbook VARCHAR(255);
    DECLARE major INTEGER;
    DECLARE minor INTEGER;
    DECLARE patch INTEGER;
    DECLARE serialized_object MEDIUMBLOB;

    -- These are bookkeeping / incidental variables needed to make this all work
    DECLARE last_cookbook VARCHAR(255) DEFAULT '';
    DECLARE current_rank INTEGER;
    DECLARE no_more_rows BOOLEAN;

    -- NOTE: All variables must be declared BEFORE cursors or handlers, or MySQL freaks out

    -- The query that makes it all happen
    DECLARE cur CURSOR FOR
        SELECT c.name, v.major, v.minor, v.patch, v.serialized_object
        FROM cookbook_versions AS v
        JOIN cookbooks AS c
          ON v.cookbook_id = c.id
        WHERE c.org_id = organization
        ORDER BY c.name, v.major DESC, v.minor DESC, v.patch DESC
    ;

    -- Gotta do this so MySQL doesn't freak out when there are no more results
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows = TRUE;

    DROP TEMPORARY TABLE IF EXISTS latest_cb_versions_temp;
    CREATE TEMPORARY TABLE latest_cb_versions_temp(
        cookbook_name VARCHAR(255),
        major INTEGER,
        minor INTEGER,
        patch INTEGER,
        serialized_object MEDIUMBLOB
    );

    OPEN cur;
    the_loop: LOOP

        FETCH cur INTO current_cookbook, major, minor, patch, serialized_object;

        IF no_more_rows THEN
            CLOSE cur;
            LEAVE the_loop;
        END IF;

        -- As we go through the cursor's results, we need to pay attention to
        -- when we "cross the boundary" between cookbooks.  We also need to be
        -- aware of how many versions we've already seen

        IF current_cookbook != last_cookbook THEN
            -- We are encountering this cookbook for the first time
            -- We always want to capture at least one version for a cookbook,
            -- so we'll go ahead and insert this one into the temp table
            SET current_rank = 1;
            INSERT INTO latest_cb_versions_temp
                VALUES(current_cookbook, major, minor, patch, serialized_object);
        ELSE
            -- We are in a block of cookbooks that we have already gotten at least one version from.
            -- Check to see if we've already taken the requisite number of versions for this cookbook
            IF current_rank < num_latest THEN
                SET current_rank = current_rank + 1;
                INSERT INTO latest_cb_versions_temp
                    VALUES(current_cookbook, major, minor, patch, serialized_object);
            END IF;
        END IF;

        -- Each time through the loop we need to record what cookbook we saw last
        SET last_cookbook = current_cookbook;

    END LOOP the_loop;
END;
EOM

    execute <<EOM
CREATE PROCEDURE latest_cookbook_versions(IN organization CHAR(32), IN num_latest INTEGER)
BEGIN
    -- Set up the information in the temporary table...
    CALL prepare_latest_cookbook_data(organization, num_latest);

    -- ... then query the temporary table in order to return the results
    --
    -- The column aliases are important, because these are what the Erchef code
    -- is expecting in order to properly process the results
    SELECT cookbook_name AS name, CONCAT_WS('.', major, minor, patch) AS version
    FROM latest_cb_versions_temp
    ORDER BY name, major DESC, minor DESC, patch DESC;
END;
EOM

  execute <<EOM
CREATE PROCEDURE cookbook_recipes(IN organization CHAR(32))
BEGIN
    -- Set up the information in the temporary table...
    CALL prepare_latest_cookbook_data(organization, 1);

    -- ... then query the temporary table in order to return the results
    --
    -- The column aliases are important, because these are what the Erchef code
    -- is expecting in order to properly process the results
    SELECT cookbook_name AS name, serialized_object
    FROM latest_cb_versions_temp
    ORDER BY name;
END;
EOM
    end # End MySQL block
  end # End up block

  down do
    case platform
    when :postgres
      execute "DROP VIEW cookbook_versions_by_rank;"
    when :mysql
      execute "DROP PROCEDURE prepare_latest_cookbook_data;"
      execute "DROP PROCEDURE latest_cookbook_versions;"
      execute "DROP PROCEDURE cookbook_recipes;"
    end
  end

end
