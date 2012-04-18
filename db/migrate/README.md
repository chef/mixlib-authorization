# RUNNING MIGRATIONS #
Cheat Sheet:

0. Install gems

      bundle install --binstubs

1. Create a db.yaml file like the following:

      adapter: mysql2
      host: localhost
      database: opscode_chef
      user: root
      password: TOPSECRETHERE

2. Now you can run the migration like so:

      bin/sequel -m db/migrate db.yaml

Read moar: <http://sequel.rubyforge.org/rdoc/files/doc/migration_rdoc.html>

# Modifying Schema #

Read here first:
https://wiki.corp.opscode.com/display/CORP/Chef+SQL+Schema
