require 'rdb_prompt'

TEST_DATABASE_YAML = <<END_TEST_DATABASE_YAML
development: 
  adapter: mysql
  username: dev_user
  database: dev_db
  password: dev_password
  host: localhost
other: 
  adapter: mysql
  username: other_user
  password: other_password
  database: other_db
  host: localhost
test_unknown_adapter:
  adapter: no_such_adapter
  username: dev_user_2
  database: dev_db_2
  password: dev_password_2
  host: localhost_2
test_mysql_env: 
  adapter: mysql
  username: dev_user_2
  database: dev_db_2
  password: dev_password_2
  host: localhost_2
test_postgres_env:
  adapter: postgresql
  database: ps_test
  pool: 5
  timeout: 5000
test_sqlite3_env:
  adapter: sqlite3
  database: test.sqlite3
  pool: 5
  timeout: 5000
END_TEST_DATABASE_YAML
