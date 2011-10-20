# Set defaults for MySQL engine and such
Sequel::MySQL.default_engine = 'InnoDB'
Sequel::MySQL.default_charset = 'utf8'
# Ensure we have a case sensitive collation on the db
Sequel::MySQL.default_collate = 'utf8_bin'

