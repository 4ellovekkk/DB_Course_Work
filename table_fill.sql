CREATE OR REPLACE PROCEDURE generate_client_info_data
    IS
    v_name         CLIENT_INFO.name%TYPE;
    v_surname      CLIENT_INFO.surname%TYPE;
    v_thirdname    CLIENT_INFO.thirdname%TYPE;
    v_birth_date   CLIENT_INFO.birth_date%TYPE;
    v_phone_number CLIENT_INFO.phone_number%TYPE;
BEGIN
    FOR i IN 1..100000
        LOOP
            -- Генерация случайных данных
            v_name := DBMS_RANDOM.STRING('A', 10); -- Замените 10 на максимальную длину имени
            v_surname := DBMS_RANDOM.STRING('A', 10); -- Замените 10 на максимальную длину фамилии
            v_thirdname := DBMS_RANDOM.STRING('A', 10); -- Замените 10 на максимальную длину отчества
            v_birth_date := TO_DATE('01-JAN-1970', 'DD-MON-YYYY') +
                            DBMS_RANDOM.VALUE(1, 200000); -- Замените границы в зависимости от ваших требований
            v_phone_number := TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1000000000, 9999999999)));
            -- Генерация случайного 10-значного номера

            -- Вставка данных в таблицу
            INSERT INTO CLIENT_INFO (name, surname, thirdname, birth_date, phone_number)
            VALUES (v_name, v_surname, v_thirdname, v_birth_date, v_phone_number);
        END LOOP;
    COMMIT;
END generate_client_info_data;
/



CREATE OR REPLACE PROCEDURE generate_random_data
    IS
    v_owner_id     int;
    v_is_locked    NUMBER(1);
    v_account_type NUMBER(1);
    v_balance      NUMBER;
BEGIN
    FOR i IN 1..100000
        LOOP
            -- Генерация случайных данных
            v_owner_id := TRUNC(DBMS_RANDOM.VALUE(145, 98124)); -- Замените границы в зависимости от ваших требований
            v_is_locked := TRUNC(DBMS_RANDOM.VALUE(0, 2));
            v_account_type := TRUNC(DBMS_RANDOM.VALUE(0, 2));
            v_balance := trunc(DBMS_RANDOM.VALUE(0, 100000), 2);
            -- Замените границы в зависимости от ваших требований

            -- Вставка данных в таблицу
            INSERT INTO CLIENT_ACCOUNT (owner, is_locked, account_type, balance)
            VALUES (v_owner_id, v_is_locked, v_account_type, v_balance);
        END LOOP;
    COMMIT;
END generate_random_data;
/

begin
    generate_client_info_data();
end;

select *
from CLIENT_INFO;

begin
    generate_random_data();
end;

select *
from CLIENT_ACCOUNT;


insert into ACTIONS(ACTION_NAME)
values ('Refill');
insert into ACTIONS(ACTION_NAME)
values ('Withdrawal');
insert into ACTIONS(ACTION_NAME)
values ('Transfer');

select *
from ACTIONS;

CREATE OR REPLACE PROCEDURE generate_account_stats_data
    IS
    v_account_id  CLIENT_ACCOUNT.id%TYPE;
    v_action_date ACCOUNT_STATS.action_date%TYPE;
    v_action_id   ACTIONS.id%TYPE;
    v_amount      ACCOUNT_STATS.amount%TYPE;
BEGIN
    FOR i IN 1..10000
        LOOP
            -- Генерация случайных данных
            v_account_id := TRUNC(DBMS_RANDOM.VALUE(145, 98124)); -- Замените границы в зависимости от ваших требований
            v_action_date := TO_DATE('01-JAN-2023', 'DD-MON-YYYY') +
                             DBMS_RANDOM.VALUE(1, 365); -- Замените границы в зависимости от ваших требований
            v_action_id := TRUNC(DBMS_RANDOM.VALUE(1, 4)); -- Значения id действий из таблицы ACTIONS (2, 3, 4)
            v_amount := DBMS_RANDOM.VALUE(1, 1000);
            -- Замените границы в зависимости от ваших требований

            -- Вставка данных в таблицу
            INSERT INTO ACCOUNT_STATS (account, action_date, action, amount)
            VALUES (v_account_id, v_action_date, v_action_id, v_amount);
        END LOOP;
    COMMIT;
END generate_account_stats_data;
/


begin
    GENERATE_ACCOUNT_STATS_DATA();
end;



select *
from ACCOUNT_STATS;
select OWNER
from CLIENT_ACCOUNT
where ID = 10870;


insert into CLERK_INFO(name, surname, thirdname, birth_date)
VALUES ('Alexey', 'Makarov', 'Igorevich', to_date('2003-04-26', 'yyyy-mm-dd'));
insert into CLERK_LOGIN_PASSWORD (ID, LOGIN, PASSWORD)
values (1, 'lexa_login', '123321');
insert into DEPOSIT_CONDITIONS(procentage_per_year, name, termin)
VALUES (15, 'Test deposit', 3);


insert into LOGIN_PASSWORD (LOGIN, PASSWORD, ID)
VALUES ('lexa_login', '123321', '15310');

commit;