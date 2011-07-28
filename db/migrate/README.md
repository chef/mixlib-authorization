# RUNNING MIGRATIONS #
Cheat Sheet:

    bundle install --binstubs
    bin/sequel -m chef-server-api/db/migrate mysql2://root@localhost/opscode_chef

Read moar: <http://sequel.rubyforge.org/rdoc/files/doc/migration_rdoc.html>
