begin
    ACCOUNT_TURNOVER(15310);
end;

begin
    ACCOUNT_HISTORY(15310, to_date('1970-01-01', 'yyyy-mm-dd'), to_date('2023-12-19', 'yyyy-mm-dd'));
end;

begin
    ACCOUNTS_AMOUNT(15310);
end;

begin
    CHANGE_CLIENT_ACCOUNT_TYPE(1, 115448);
end;

begin
    CHECK_BALANCE(1);
end;

begin
    CLERK_LOGIN('lexa_login', '123321');
end;

begin
    CLIENT_CREATION('Sanya1', 'Sakovich', 'Viktorovich', to_date('2003-10-12', 'yyyy-mm-dd'), '375333456789$');
end;

select *
from CLIENT_INFO
where NAME = 'Sanya';


begin
    CLIENT_DELETE(916);
end;
select OWNEr from CLIENT_ACCOUNT where BALANCE >0;
update CLIENT_ACCOUNT
set BALANCE=0
where OWNER = 916;
commit;
select *
from CLIENT_ACCOUNT
where OWNER = 44879;
commit;

--client_info_changing not checked
begin
    CREATE_DEPOSIT(15311, 1, 10.24);
end;

begin
    CREATE_ACCOUNT_FOR_CLIENT(15310, 0);
end;

select *
from CLIENT_ACCOUNT
where OWNER = 15310
  and ACCOUNT_TYPE = 1
  and BALANCE = 10.11;
select *
from DEPOSIT_STATE;

begin
    COUNT_DEPOSIT_PROFIT(101592, 15310);
end;

begin
    DELETE_ACCOUNT_FOR_CLIENT(15310, 47405);
end;
begin
    EXPORT_CLIENT_INFO();
end;

begin
    GET_USER_INFO(15310);
end;


BEGIN
    READ_JSON_FILE('your_filename.json');
END;

select *
from LOGIN_PASSWORD;
begin
    LOGIN_CLIENT('lexa_login', '123321');
end;

begin
    OPERATIONS_AMOUNT(to_date('1970-01-01', 'yyyy-mm-dd'), to_date('2023-12-10', 'yyyy-mm-dd'), 15310, 44869);
end;

--
--  SELECT count(*)
--         FROM ACCOUNT_STATS
--                  INNER JOIN VYDRA_DBA.CLIENT_ACCOUNT CA ON CA.ID = ACCOUNT_STATS.ACCOUNT
--         WHERE CA.OWNER = 15310
--           AND ACTION_DATE >= to_date('1970-01-01','yyyy-mm-dd')
--           AND ACTION_DATE <= to_date('2023-12-10','yyyy-mm-dd');
begin
    REFILL_ACCOUNT(44869, 10);
end;

begin
    REGISTER_CLIENT('lexa_login2', '123321', 15310);
end;

begin
    TRANSFER(44869, 43645, 15310, 10);
end;

begin
    WITHDRAWAL(44869, 10, 15310);
end;
select *
from CLIENT_INFO;

select *
from ACCOUNT_STATS
where ACCOUNT = 56827
   or ACCOUNT = 44869
   or ACCOUNT = 47405
   or ACCOUNT = 43645
   or ACCOUNT = 101592;

select *
from CLIENT_ACCOUNT
where OWNER = 15310;
--44869 account
--15310 client
select *
from CLIENT_ACCOUNT;

select *
from CLIENT_ACCOUNT
where OWNER = 15310;
select *
from CLIENT_INFO
where ID = 15310;
select *
from CLIENT_ACCOUNT
where OWNER = 15310;

select *
from ACCOUNT_STATS
where ACCOUNT = 44869;

begin
    create_deposit_condition(10, 'tets1', 4);
end;
select *
from DEPOSIT_CONDITIONS;

begin
    delete_deposit_condition(42);
end;

select count(*)
from CLIENT_INFO;



select CLIENT_INFO.ID, surname, thirdname, birth_date, CLIENT_ACCOUNT.ID, CLIENT_ACCOUNT.BALANCE
from CLIENT_INFO
         inner join CLIENT_ACCOUNT on CLIENT_INFO.ID = CLIENT_ACCOUNT.OWNER;


CREATE INDEX client_info__idx
    ON client_info (name, surname, BIRTH_DATE);


begin
    GET_USER_INFO(44312);
end;

select * from CLIENT_ACCOUNT where OWNER=44312;

update CLIENT_ACCOUNT set IS_LOCKED=1 where ID=79489;
commit ;
begin
    REFILL_ACCOUNT(79489,20);
end;

select * from DEPOSIT_STATE;
select * from DEPOSIT_CONDITIONS;

begin
    COUNT_DEPOSIT_PROFIT(101592,15310);
end;