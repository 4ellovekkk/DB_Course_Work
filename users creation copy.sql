create  tablespace CLIENT_DATA
datafile '/opt/oracle/oradata/ORCLCDB/ORCLPDB/client_data.dbf'
size 100m;

create  tablespace CLIERK_DATA
datafile '/opt/oracle/oradata/ORCLCDB/ORCLPDB/clerk_data.dbf'
size 100m;

create temporary tablespace  CLIENT_TMP_DATA
tempfile '/opt/oracle/oradata/ORCLCDB/ORCLPDB/client_temp_data.tmp'
size 200m;

create temporary tablespace  CLERK_TMP_DATA
tempfile '/opt/oracle/oradata/ORCLCDB/ORCLPDB/clerk_temp_data.tmp'
size 200m;

create role client_role;
create role clerk_role;

alter session set container = ORCLPDB;

grant create session to client_role;
grant connect to client_role;

grant connect, create session to clerk_role;

commit ;
select * from dba_roles where ROLE like '%CL%';
select * from SYS.DBA_ROLE_PRIVS where GRANTEE like '%CL%';

create profile def_bank_clerk limit
    sessions_per_user 3
    failed_login_attempts 7
    password_lock_time 1
    password_reuse_time 10
    password_grace_time default
    connect_time 180
    idle_time 30;
create profile def_client limit
    sessions_per_user 2
    failed_login_attempts 5
    password_lock_time 1
    password_reuse_time 10
    password_grace_time default
    connect_time 180
    idle_time 30;
select * from SYS.DBA_PROFILES where profile like '%DEF%';

