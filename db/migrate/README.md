# RUNNING MIGRATIONS #
Cheat Sheet:

    bundle install --binstubs
    bin/sequel -m chef-server-api/db/migrate mysql2://root@localhost/opscode_chef

Read moar: <http://sequel.rubyforge.org/rdoc/files/doc/migration_rdoc.html>

# Modifying Schema #

Read here first:
https://wiki.corp.opscode.com/display/CORP/Chef+SQL+Schema

# Private Chef opscode-dev-vm  Notes #

Mount your local host-based copy of `mixlib-authorization` in the Private Chef
guest:

    helsinki:~OC/opscode-dev-vm$ rake project:load[mixlib-authorization]
    [vagrant] name => mixlib-authorization
    [vagrant] host path => /Users/schisamo/dev/code/opscode/mixlib-authorization
    [vagrant] guest path => /opt/opscode/embedded/service/mixlib-authorization
    [default] Mounting host directory '/Users/schisamo/dev/code/opscode/mixlib-authorization' as guest directory '/srv/piab/mounts/mixlib-authorization'
    [vagrant] Creating shared folders metadata...
    [vagrant] Mounting shared folders...
    [vagrant] -- mixlib-authorization: /srv/piab/mounts/mixlib-authorization
    [default] stdin: is not a tty
    [default] Fetching source index for http://rubygems.org/
    [default] Using rake (0.9.2)
    [default] Using activesupport (3.0.9)
    [default]
    [default] Using builder (2.1.2)
    [default] Using i18n (0.5.0)
    ...
    [default] Using rspec (2.6.0)
    [default] Using uuid (2.3.4)
    [default] Using bundler (1.0.22)
    [default] Your bundle is complete! It was installed into /opt/opscode/embedded/service/gem

SSH into the Private Chef guest:

    helsinki:~OC/opscode-dev-vm$ rake ssh
    Linux private-chef.opscode.piab 2.6.32-38-server #83-Ubuntu SMP Wed Jan 4 11:26:59 UTC 2012 x86_64 GNU/Linux
    Ubuntu 10.04.4 LTS

    Welcome to the Ubuntu Server!
     * Documentation:  http://www.ubuntu.com/server/doc
    Last login: Mon Mar 12 14:36:32 2012 from 10.0.2.2
    vagrant@private-chef:~$

Ensure the guest's `PATH` is set correctly (this should be set by a Bonfire
`after_start` callback):

    vagrant@private-chef:~$ echo $PATH
    /opt/opscode/embedded/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/opt/ruby/bin

If `/opt/opscode/embedded/bin` is not listed first in the `PATH` make it so:

    export PATH=/opt/opscode/embedded/bin:$PATH

Change to `mixlib-authorization` directory and run migrations:

    vagrant@private-chef:~$ cd /opt/opscode/embedded/service/mixlib-authorization
    vagrant@private-chef:/opt/opscode/embedded/service/mixlib-authorization$ bundle exec sequel -m db/migrate postgres://opscode-pgsql@127.0.0.1/opscode_chef

Verify everything migrated correctly:

    vagrant@private-chef:/opt/opscode/embedded/service/mixlib-authorization$ psql opscode_chef opscode-pgsql
    psql (9.1.2)
    Type "help" for help.

    opscode_chef=# \d
                         List of relations
     Schema |         Name          |   Type   |     Owner
    --------+-----------------------+----------+---------------
     public | clients               | table    | opscode-pgsql
     public | external_authn        | table    | opscode-pgsql
     public | external_authn_id_seq | sequence | opscode-pgsql
     public | nodes                 | table    | opscode-pgsql
     public | schema_info           | table    | opscode-pgsql
     public | users                 | table    | opscode-pgsql
    (6 rows)

    opscode_chef=# \l
                                            List of databases
         Name     |     Owner     | Encoding  | Collate | Ctype |          Access privileges
    --------------+---------------+-----------+---------+-------+-------------------------------------
     opscode_chef | opscode-pgsql | UTF8      | C       | C     | =Tc/"opscode-pgsql"                +
                  |               |           |         |       | "opscode-pgsql"=CTc/"opscode-pgsql"+
                  |               |           |         |       | opscode_chef=CTc/"opscode-pgsql"   +
                  |               |           |         |       | opscode_chef_ro=CTc/"opscode-pgsql"
     postgres     | opscode-pgsql | SQL_ASCII | C       | C     |
     template0    | opscode-pgsql | SQL_ASCII | C       | C     | =c/"opscode-pgsql"                 +
                  |               |           |         |       | "opscode-pgsql"=CTc/"opscode-pgsql"
     template1    | opscode-pgsql | SQL_ASCII | C       | C     | =c/"opscode-pgsql"                 +
                  |               |           |         |       | "opscode-pgsql"=CTc/"opscode-pgsql"
    (4 rows)

    opscode_chef=# select * from schema_info;
     version
    ---------
           4
    (1 row)

    opscode_chef=# \q

