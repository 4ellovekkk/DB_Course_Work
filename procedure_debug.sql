begin
    ACCOUNT_TURNOVER(199799);
end;

begin
    ACCOUNT_HISTORY(1,to_date('1970-01-01','yyyy-mm-dd'),to_date('2023-12-19','yyyy-mm-dd'));
end;

begin
    ACCOUNTS_AMOUNT(1);
end;

begin
    CHANGE_CLIENT_ACCOUNT_TYPE(1,115448);
end;

begin
    CHECK_BALANCE(1);
end;

begin
CLERK_LOGIN('lexa_loginnegr','123321');
end;

begin
    CLIENT_CREATION('Sanya','Sakovich','Viktorovich',to_date('2003-10-12','yyyy-mm-dd'),'375333456789$');
end;

select * from CLIENT_INFO where NAME='Sanya';

begin
    CLIENT_DELETE(200001);
end;

--client_info_changing not checked
begin
    CLIENT_INFO_CHANGING(10,'Test','Man','','375295357399');
end;

begin
    CREATE_DEPOSIT(199789,1,10.21);
end;

select * from CLIENT_ACCOUNT where OWNER=199799 and ACCOUNT_TYPE=1 and BALANCE=10.11;
select * from DEPOSIT_STATE ;

begin
    COUNT_DEPOSIT_PROFIT(162912,199799);
end;



select * from CLIENT_INFO;

select * from CLIENT_ACCOUNT where OWNER=199799;
--115448 account
--199799 client
select * from CLIENT_ACCOUNT;