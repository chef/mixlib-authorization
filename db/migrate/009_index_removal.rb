require File.expand_path('../settings', __FILE__)

Sequel.migration do
  change do
    # Remove some superfluous indexes
    #
    # Postgres can utilize a multicolumn index (say, on [a,b,c]) for
    # queries that involve a subset of those columns, particularly the
    # left-most ones (i.e., just [a]).  Thus, we can save the space
    # needed for an index on "org_id" by re-using the UNIQUE index on
    # ["org_id", "name"].  The cost would be potentially slower
    # searches of the index, given that it will be larger.  The
    # specifics of this cost, however, have not been quantified (but I
    # don't think that a cost/benefit analysis of having an extra
    # index lying around, taking up space in the cache has been
    # performed, either).  Erring on the side of "less stuff" and a
    # simpler schema.
    #
    # See http://www.postgresql.org/docs/9.1/static/indexes-bitmap-scans.html
    #
    # MySQL has similar behavior:
    # http://dev.mysql.com/doc/refman/5.6/en/multiple-column-indexes.html

    # Index on clients, environments, roles, data_bags subsumed by the
    # unique index on [org_id, name]
    #
    # Index on nodes subsumed by the unique index on [org_id, name],
    # as well as [org_id, environment]
    #
    # Index on data_bag_items subsumed by the unique index on [org_id,
    # databag_name, item_name]
    [:clients, :environments, :nodes, :roles, :data_bags, :data_bag_items].each do |table|
      alter_table(table) do
        drop_index :org_id
      end
    end
  end
end
