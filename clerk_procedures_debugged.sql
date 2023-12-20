create PROCEDURE CHANGE_CLIENT_ACCOUNT_TYPE(p_user_id IN INT, p_client_account IN INT) AS
    v_if_exists    INT;
    v_account_type INT;
BEGIN
    -- Check if the account with the given ID and client ID exists
    SELECT COUNT(*)
    INTO v_if_exists
    FROM CLIENT_ACCOUNT
    WHERE ID = p_client_account
      AND OWNER = p_user_id;

    -- Handle the case when the account does not exist
    IF v_if_exists = 0 THEN
        -- Raise an exception for non-existent client or account
        RAISE_APPLICATION_ERROR(-20001, 'Client with ID ' || p_user_id || ' or account with ID ' || p_client_account ||
                                        ' does not exist');
        RETURN;
    ELSE
        -- Get the current account type
        SELECT ACCOUNT_TYPE
        INTO v_account_type
        FROM CLIENT_ACCOUNT
        WHERE ID = p_client_account
          AND OWNER = p_user_id;

        -- Toggle the account type
        IF v_account_type = 0 THEN
            UPDATE CLIENT_ACCOUNT
            SET ACCOUNT_TYPE = 1
            WHERE ID = p_client_account
              AND OWNER = p_user_id;
        ELSE
            UPDATE CLIENT_ACCOUNT
            SET ACCOUNT_TYPE = 0
            WHERE ID = p_client_account
              AND OWNER = p_user_id;
        END IF;

        DBMS_OUTPUT.PUT_LINE('Account type changed successfully');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        RAISE_APPLICATION_ERROR(-20002, 'An error occurred: ' || SQLERRM);
END CHANGE_CLIENT_ACCOUNT_TYPE;
/



create PROCEDURE CLERK_LOGIN(
    p_login IN nvarchar2,
    p_password IN NVARCHAR2
) AS
    v_is_exists NUMBER;

BEGIN
    -- Check for null parameters
    IF p_login IS NULL OR p_password IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters passed');
    END IF;

    -- Check login and password in CLERK_LOGIN_PASSWORD table
    SELECT COUNT(*)
    INTO v_is_exists
    FROM CLERK_LOGIN_PASSWORD
    WHERE LOGIN = p_login
      AND PASSWORD = p_password;

    -- Handle incorrect login or password
    IF v_is_exists != 1 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect login or password');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Worker logged in successfully');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect login or password');
    WHEN TOO_MANY_ROWS THEN
        RAISE_APPLICATION_ERROR(-20003,
                                'Multiple records found for the same login and password. Data integrity issue.');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
END CLERK_LOGIN;
/

create PROCEDURE CLIENT_CREATION(
    p_name IN NVARCHAR2,
    p_surname IN NVARCHAR2,
    p_thirdname IN NVARCHAR2 DEFAULT NULL,
    p_birth_date IN DATE,
    p_phone_number NVARCHAR2
)
AS
    v_if_exists int;
BEGIN
    -- Check if the phone number is a valid number
    -- Insert into CLIENT_INFO
    IF p_name IS NOT NULL AND p_surname IS NOT NULL AND p_birth_date IS NOT NULL AND p_phone_number IS NOT NULL and
       (extract(year from p_birth_date) <= (extract(year from sysdate) - 18)) and length(p_phone_number) = 13 and
       REGEXP_LIKE(p_phone_number, '^[0-9]') THEN
        select count(*)
        into v_if_exists
        from CLIENT_INFO
        where NAME = p_name
          and SURNAME = p_surname
          and BIRTH_DATE = p_birth_date
          and PHONE_NUMBER = p_phone_number;

        --INSERT INTO CLIENT_INFO(name, surname, thirdname, birth_date, phone_number)
        --VALUES (p_name, p_surname, NVL(p_thirdname, ''), p_birth_date, p_phone_number);
        --DBMS_OUTPUT.PUT_LINE('Client registered successfully');
    ELSE
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect client data');
    END IF;
    if v_if_exists = 0 then
        INSERT INTO CLIENT_INFO(name, surname, thirdname, birth_date, phone_number)
        VALUES (p_name, p_surname, NVL(p_thirdname, ''), p_birth_date, p_phone_number);
        DBMS_OUTPUT.PUT_LINE('Client registered successfully');
    else
        RAISE_APPLICATION_ERROR(-20001, 'Client with given parametres already exists');
    end if;
EXCEPTION
    WHEN VALUE_ERROR THEN
        RAISE_APPLICATION_ERROR(-20002, 'Invalid value for phone number');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred during client creation: ' || SQLERRM);
END client_creation;
/

create PROCEDURE CLIENT_DELETE(p_client_id IN INT) AS
    v_is_client_exists             INT;
    v_accounts_avalible_for_delete int;
    v_total_avccounts              int;

    -- Exception for no rows found
    NO_ROWS_FOUND EXCEPTION;
    PRAGMA EXCEPTION_INIT (NO_ROWS_FOUND, -20001);

    -- Exception for too many rows found
    TOO_MANY_ROWS EXCEPTION;
    PRAGMA EXCEPTION_INIT (TOO_MANY_ROWS, -20002);

    -- Exception for general error during deletion
    DELETE_ERROR EXCEPTION;
    PRAGMA EXCEPTION_INIT (DELETE_ERROR, -20003);

BEGIN
    -- Check if the client exists
    BEGIN
        SELECT COUNT(*)
        INTO v_is_client_exists
        FROM CLIENT_INFO
        WHERE ID = p_client_id;

        IF v_is_client_exists != 1 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Incorrect client id ');
        END IF;
    EXCEPTION
        WHEN NO_ROWS_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'No client found with the specified ID.');
        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(-20003, 'Multiple clients found with the same ID. Data integrity issue.');
    END;

    -- Delete the client
    BEGIN
        select count(*)
        into v_accounts_avalible_for_delete
        from CLIENT_ACCOUNT
                 inner join DEPOSIT_STATE on CLIENT_ACCOUNT.ID = DEPOSIT_STATE.ACCOUNT_FOR_PAY
        where CLIENT_ACCOUNT.BALANCE = 0
          and DEPOSIT_STATE.CURRENT_AMOUNT = 0
          and CLIENT_ACCOUNT.OWNER = p_client_id;
        select count(*) into v_total_avccounts from CLIENT_ACCOUNT where OWNER = p_client_id;
        if v_accounts_avalible_for_delete = v_total_avccounts then
            Delete from CLIENT_ACCOUNT where OWNER = p_client_id;
            DELETE
            FROM CLIENT_INFO
            WHERE ID = p_client_id;
            DBMS_OUTPUT.PUT_LINE('Client deleted Successfully');
        else
            RAISE_APPLICATION_ERROR(-20001, 'Client have money on theirs account, delete operation unavailable ');
        end if;
    EXCEPTION
        WHEN
            OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'An error occurred during client deletion: ' || SQLERRM);
        -- Optionally, you can log or handle the error as needed.
    END;
END CLIENT_DELETE;
/

create PROCEDURE CREATE_ACCOUNT_FOR_CLIENT(p_client_id IN INT, p_account_type IN INT) AS
    v_is_client_exists INT;
BEGIN
    -- Check if the client with the given ID exists
    SELECT COUNT(*)
    INTO v_is_client_exists
    FROM CLIENT_INFO
    WHERE ID = p_client_id;

    -- Handle the case when the client does not exist
    IF v_is_client_exists = 0 THEN
        -- Raise an exception for non-existent client
        RAISE_APPLICATION_ERROR(-20001, 'Client with ID ' || p_client_id || ' does not exist');
        RETURN;
    END IF;

    -- Insert a new account for the client
    INSERT INTO CLIENT_ACCOUNT (OWNER, IS_LOCKED, ACCOUNT_TYPE, BALANCE)
    VALUES (p_client_id, 0, p_account_type, 0);

    DBMS_OUTPUT.PUT_LINE('Account created successfully');

EXCEPTION
    WHEN VALUE_ERROR THEN
        -- Handle the case when a value error occurs (e.g., incorrect parameter type)
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameter type');
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        RAISE_APPLICATION_ERROR(-20003, 'An error occurred: ' || SQLERRM);
END CREATE_ACCOUNT_FOR_CLIENT;
/

create PROCEDURE CREATE_DEPOSIT(
    p_user_id IN INT,
    p_deposit_condition IN INT,
    p_amount IN NUMBER
) AS
    v_account_id INT;
    v_if_exists INT;
BEGIN
    -- Проверка на существование пользователя
    SELECT COUNT(*) INTO v_if_exists FROM CLIENT_INFO WHERE ID = p_user_id;

    IF v_if_exists != 1 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Incorrect user id');
    END IF;

    IF p_deposit_condition IS NOT NULL AND p_amount IS NOT NULL THEN
        -- Вставка записи в таблицу CLIENT_ACCOUNT
        INSERT INTO CLIENT_ACCOUNT(owner, is_locked, account_type, balance)
        VALUES (p_user_id, 0, 1, p_amount);
    END IF;

    -- Получение ID созданного счета
    SELECT ID
    INTO v_account_id
    FROM CLIENT_ACCOUNT
    WHERE ROWNUM = 1
      AND ACCOUNT_TYPE = 1
    ORDER BY ID DESC;

    -- Вставка записи в таблицу DEPOSIT_STATE
    INSERT INTO DEPOSIT_STATE(owner, current_amount, account_for_pay, deposit_type, start_date)
    VALUES (p_user_id, p_amount, v_account_id, p_deposit_condition, TRUNC(SYSDATE));

    DBMS_OUTPUT.PUT_LINE('Successfully created deposit for client with id: ' || p_user_id);
    DBMS_OUTPUT.PUT_LINE('Account for deposit is: ' || v_account_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'No data found for the specified conditions');
    WHEN VALUE_ERROR THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid value passed');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004, 'An error occurred: ' || SQLERRM);
END CREATE_DEPOSIT;
/

create procedure create_deposit_condition(p_percentage in int, p_name nvarchar2, p_termin in int)
as
    begin
        if p_percentage is null or p_name is null or p_termin is null then raise_application_error(-20001,'Conditions is incorrect'); end if;
        if p_termin>0 and p_percentage>0 then
       insert into DEPOSIT_CONDITIONS(procentage_per_year, name, termin) values (p_percentage,p_name,p_termin);
       dbms_output.put_line('Deposit condition created successfully');
            commit;
            else raise_application_error(-20001,'Incorrect parametres');
        end if;
    end;
/

create PROCEDURE DELETE_ACCOUNT_FOR_CLIENT(p_client_id IN INT, p_account_id IN INT) AS
    v_if_exists INT;
BEGIN
    -- Check if the account with the given ID and client ID exists
    SELECT COUNT(*)
    INTO v_if_exists
    FROM CLIENT_ACCOUNT
    WHERE ID = p_account_id
      AND OWNER = p_client_id;

    -- Handle the case when the account does not exist
    IF v_if_exists = 0 THEN
        -- Raise an exception for non-existent client or account
        RAISE_APPLICATION_ERROR(-20001, 'Client with ID ' || p_client_id || ' or account with ID ' || p_account_id ||
                                        ' does not exist');
    end if;
    -- Delete the account
    select BALANCE into v_if_exists from CLIENT_ACCOUNT where OWNER = p_client_id and ID = p_account_id;
    if v_if_exists = 0 then
        select IS_LOCKED into v_if_exists from CLIENT_ACCOUNT where OWNER = p_client_id and ID = p_account_id;
        if v_if_exists = 0 then
            DELETE
            FROM CLIENT_ACCOUNT
            WHERE OWNER = p_client_id
              AND ID = p_account_id;
            DBMS_OUTPUT.PUT_LINE('Account deleted successfully');
        else
            raise_application_error(-20001, 'Given account is locked');
        end if;
    else
        raise_application_error(-20001, 'Given account is not empty');
    end if;

EXCEPTION
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        RAISE_APPLICATION_ERROR(-20002, 'An error occurred: ' || SQLERRM);
END DELETE_ACCOUNT_FOR_CLIENT;
/

create procedure delete_deposit_condition(p_condition_id in int)
as
    v_if_exists int;
        v_if_accounts int;
begin
    if p_condition_id is null then raise_application_error(-20001, 'Condition id is null'); end if;
    select count(*) into v_if_exists from DEPOSIT_CONDITIONS where ID = p_condition_id;
    select count(*) into v_if_accounts from DEPOSIT_STATE inner join DEPOSIT_CONDITIONS on DEPOSIT_STATE.DEPOSIT_TYPE = DEPOSIT_CONDITIONS.ID where (extract(year from START_DATE)+TERMIN)<extract(year from sysdate);
    if v_if_exists > 0 and v_if_accounts=0 then
        delete from DEPOSIT_CONDITIONS where ID = p_condition_id;
        DBMS_OUTPUT.PUT_LINE('Deposit condition deleted successfully');
        commit;
    else
        raise_application_error(-20001, 'No deposit condition with such id or deposits with this condition didnt expired');
    end if;
end delete_deposit_condition;
/

