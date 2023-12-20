create role client_role;
create role clerk_role;

alter session set container = ORCLPDB1;

grant create session to client_role;
grant connect to client_role;

grant connect, create session to clerk_role;

commit;
select *
from dba_roles
where ROLE like '%CL%';
select *
from SYS.DBA_ROLE_PRIVS
where GRANTEE like '%CL%';

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
alter session set container =orclpdb1;
select *
from DBA_PROFILES
where PROFILE like '%DEF_%';
---
create user clerk1 identified by pasword1
    default tablespace CLIERK_DATA quota unlimited on CLIERK_DATA
    temporary tablespace CLERK_TMP_DATA
    profile def_bank_clerk
    account unlock;
grant clerk_role to clerk1;


create user client1 identified by pasword1
    default tablespace CLIENT_DATA quota unlimited on CLIERK_DATA
    temporary tablespace CLIENT_TMP_DATA
    profile def_client
    account unlock;
grant client_role to client1;
commit;


