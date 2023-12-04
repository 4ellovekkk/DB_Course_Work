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

create tablespace BANK_DATA
datafile '/opt/oracle/oradata/ORCLCDB/ORCLPDB/bank_data.dbf'
size 200m;