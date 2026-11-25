SELECT 'CREATE ROLE replicator WITH REPLICATION LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replicator')\gexec
SELECT 'CREATE ROLE evl_backup WITH REPLICATION LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'evl_backup')\gexec
SELECT 'CREATE ROLE evl_app WITH LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'evl_app')\gexec
SELECT 'CREATE ROLE evl_owner WITH NOLOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'evl_owner')\gexec
SELECT 'CREATE ROLE prometheus WITH LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'prometheus')\gexec

ALTER ROLE replicator PASSWORD :'repl_pw';
ALTER ROLE evl_backup PASSWORD :'backup_pw';
ALTER ROLE evl_app PASSWORD :'app_pw';
ALTER ROLE evl_app CONNECTION LIMIT 60;
GRANT pg_read_all_data TO evl_backup;
GRANT pg_monitor TO prometheus;

SELECT 'CREATE DATABASE evlocker OWNER evl_owner'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'evlocker')\gexec
REVOKE ALL ON DATABASE evlocker FROM PUBLIC;
GRANT CONNECT ON DATABASE evlocker TO evl_app, evl_backup;
