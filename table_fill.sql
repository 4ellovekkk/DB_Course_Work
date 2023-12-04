CREATE OR REPLACE PROCEDURE insert_rows_client_info AS
BEGIN
  FOR i IN 1..100000 LOOP
    INSERT INTO CLIENT_INFO (name, surname, thirdname, birth_date, phone_number)
    VALUES (TO_CHAR(i),TO_CHAR(2*i),TO_CHAR(3*i),TRUNC(SYSDATE),TO_CHAR(i*i));
  END LOOP;
  COMMIT; -- Фиксация изменений
END;

begin
    insert_rows_client_info();
end;

select * from CLIENT_INFO where ID>9500 order by ID;

delete from CLIENT_INFO;



CREATE OR REPLACE PROCEDURE insert_rows_client_account AS
BEGIN
  FOR i IN 1..100000 LOOP
    INSERT INTO CLIENT_ACCOUNT (OWNER, IS_LOCKED, ACCOUNT_TYPE, BALANCE)
    VALUES (i, 0, 1, TRUNC((10 + DBMS_RANDOM.value * 10), 5));
  END LOOP;
  COMMIT;
END;

select * from CLIENT_INFO where id<1000;
begin
    insert_rows_client_account();
end;
select * from CLIENT_ACCOUNT;
delete from CLIENT_ACCOUNT;