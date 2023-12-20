create PROCEDURE account_history(
    p_account_id IN NUMBER,
    p_from_date IN DATE,
    p_to_date IN DATE
)
AS
    CURSOR c_account_history IS
        SELECT ACTION_DATE, ACTION_NAME, ACCOUNT
        FROM ACCOUNT_STATS
                 INNER JOIN VYDRA_DBA.CLIENT_ACCOUNT CA ON CA.ID = ACCOUNT_STATS.ACCOUNT
                 inner join ACTIONS on ACCOUNT_STATS.ACTION = ACTIONS.ID
        WHERE CA.OWNER = p_account_id
          AND ACTION_DATE >= p_from_date
          AND ACTION_DATE <= p_to_date;
    v_operation_date DATE;
    v_operation      NVARCHAR2(50);
    v_account        INT;
    v_if_exists      int;

BEGIN
    -- Validate input parameters
    BEGIN
        IF p_account_id IS NULL OR p_from_date IS NULL OR p_to_date IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Invalid input parameters. Please provide valid values.');
        END IF;
        select count(*) into v_if_exists from CLIENT_ACCOUNT where ID = p_account_id;
        if v_if_exists = 0 then
            RAISE_APPLICATION_ERROR(-20002, 'Client with given id does not exists');
        end if;

        -- Check if from_date is less than or equal to to_date
        IF p_from_date > p_to_date THEN
            RAISE_APPLICATION_ERROR(-20002,
                                    'Invalid date range. "From date" should be less than or equal to "To date".');
        END IF;
    EXCEPTION
        WHEN
            VALUE_ERROR THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect type of parameter was passed');
    END;

    OPEN c_account_history;

    BEGIN
        LOOP
            FETCH c_account_history INTO v_operation_date, v_operation, v_account;
            EXIT WHEN c_account_history%NOTFOUND;

            -- Process the selected data as needed
            DBMS_OUTPUT.PUT_LINE('Account ID: ' || p_account_id ||
                                 ', Operation Date: ' || v_operation_date ||
                                 ', Operation: ' || v_operation);
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'No records found for the specified account and date range.');
    END;

    CLOSE c_account_history;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
END account_history;
/


create PROCEDURE account_turnover(p_user_id IN INT)
AS
    v_total_sum NUMBER := 0;
    v_if_exists number := 0;
    CURSOR c_values_for_user IS
        SELECT amount
        FROM ACCOUNT_STATS
                 INNER JOIN CLIENT_ACCOUNT ON ACCOUNT_STATS.ACCOUNT = CLIENT_ACCOUNT.ID
        WHERE OWNER = p_user_id
          AND AMOUNT IS NOT NULL;

BEGIN
    select count(*) into v_if_exists from CLIENT_INFO where ID = p_user_id;
    if v_if_exists = 0 then
        RAISE_APPLICATION_ERROR(-20001, 'No user found ' || p_user_id);
    end if;
    FOR r_value IN c_values_for_user
        LOOP
            v_total_sum := v_total_sum + r_value.AMOUNT;
        END LOOP;

    IF v_total_sum IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'No data found for user ' || p_user_id);
    ELSE
        v_total_sum := trunc(v_total_sum, 2);
        DBMS_OUTPUT.PUT_LINE('Total sum for user ' || p_user_id || ': ' || v_total_sum);
    END IF;

EXCEPTION
    WHEN
        NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'No data found for user ' || p_user_id);
    WHEN
        OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'An error occurred: ' || SQLERRM);
END;
/



create PROCEDURE accounts_amount(p_client_id IN INT)
AS
    v_param_check_number INT;
    v_amount             INT;
BEGIN
    -- Проверка на отрицательное значение счета
    BEGIN
        v_param_check_number := TO_NUMBER(p_client_id);
        select count(*) into v_param_check_number from CLIENT_INFO where ID = p_client_id;
        if v_param_check_number = 0 then
            RAISE_APPLICATION_ERROR(-20002, 'User with given id does not exists');
        end if;
        -- Проверка на NULL
        IF p_client_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters passed');
        END IF;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters type');
    END;

    -- Подсчет количества счетов для текущего пользователя
    BEGIN
        SELECT COUNT(*) INTO v_amount FROM CLIENT_ACCOUNT WHERE OWNER = p_client_id;

        IF v_amount > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Amount of accounts for current user is: ' || v_amount);
        ELSE
            RAISE_APPLICATION_ERROR(-20003, 'No records found for the specified account');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
    END;
END accounts_amount;
/


create or replace PROCEDURE CHANGE_CLIENT_ACCOUNT_TYPE(p_user_id IN INT, p_client_account IN INT) AS
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



create PROCEDURE check_balance(client_id IN NUMBER)
AS
    v_param_test NUMBER;
    v_account_id CLIENT_ACCOUNT.id%TYPE;
    v_balance    CLIENT_ACCOUNT.balance%TYPE;
    CURSOR c_account_info IS
        SELECT ID, BALANCE
        FROM CLIENT_ACCOUNT
        WHERE OWNER = client_id;

BEGIN
    -- Validate that the provided parameter is a positive integer
    BEGIN
        v_param_test := TO_NUMBER(client_id);
        IF client_id IS NULL OR client_id <= 0 OR client_id != TRUNC(client_id) THEN
            RAISE_APPLICATION_ERROR(-20002, 'Invalid client ID provided.');
        END IF;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect type of parameter was passed');
    END;

    -- Select account information
    OPEN c_account_info;
    LOOP
        FETCH c_account_info INTO v_account_id, v_balance;
        v_balance := trunc(v_balance, 2);
        EXIT WHEN c_account_info%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('Account ID: ' || v_account_id || ' Balance: ' || v_balance);
    END LOOP;
    CLOSE c_account_info;

    IF v_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20003, 'No account information found for client ID ' || client_id);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred for client ID ' || client_id || ': ' || SQLERRM);
END check_balance;
/

create or replace PROCEDURE CLERK_LOGIN(
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

create PROCEDURE CLIENT_INFO_CHANGING(
    p_client_id IN INT,
    p_name IN NVARCHAR2,
    p_surname IN NVARCHAR2,
    p_thirdname IN NVARCHAR2,
    p_phone_number IN NVARCHAR2
) AS
    v_phone_check NUMBER;
    v_if_exists   number;

    -- Exception for invalid phone number
    INVALID_PHONE EXCEPTION;
    PRAGMA EXCEPTION_INIT (INVALID_PHONE, -6502);

    -- Exception for no rows updated
    NO_ROWS_UPDATED EXCEPTION;
    PRAGMA EXCEPTION_INIT (NO_ROWS_UPDATED, -1422);
BEGIN
    select count(*) into v_if_exists from CLIENT_INFO where ID = p_client_id;
    if v_if_exists != 1 then
        RAISE_APPLICATION_ERROR(-20001, 'Incorrect client id');
    end if;
    -- Check if the phone number is a valid number
    BEGIN
        v_phone_check := TO_NUMBER(p_phone_number);
    EXCEPTION
        WHEN VALUE_ERROR THEN
            RAISE INVALID_PHONE;
    END;

    -- Update operations with error handling
    BEGIN
        IF p_name IS NOT NULL THEN
            UPDATE CLIENT_INFO SET NAME = p_name WHERE ID = p_client_id;
        END IF;
    EXCEPTION
        WHEN NO_ROWS_UPDATED THEN
            DBMS_OUTPUT.PUT_LINE('No rows updated for NAME');
    END;

    BEGIN
        IF p_surname IS NOT NULL THEN
            UPDATE CLIENT_INFO SET SURNAME = p_surname WHERE ID = p_client_id;
        END IF;
    EXCEPTION
        WHEN NO_ROWS_UPDATED THEN
            DBMS_OUTPUT.PUT_LINE('No rows updated for SURNAME');
    END;

    BEGIN
        IF p_thirdname IS NOT NULL THEN
            UPDATE CLIENT_INFO SET THIRDNAME = p_thirdname WHERE ID = p_client_id;
        END IF;
    EXCEPTION
        WHEN NO_ROWS_UPDATED THEN
            DBMS_OUTPUT.PUT_LINE('No rows updated for THIRD NAME');
    END;

    BEGIN
        IF p_phone_number IS NOT NULL THEN
            UPDATE CLIENT_INFO SET PHONE_NUMBER = p_phone_number WHERE ID = p_client_id;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Client edited successfully');
    EXCEPTION
        WHEN NO_ROWS_UPDATED THEN
            DBMS_OUTPUT.PUT_LINE('No rows updated for PHONE NUMBER');
        WHEN INVALID_PHONE THEN
            DBMS_OUTPUT.PUT_LINE('Invalid phone number');
    END;
END CLIENT_INFO_CHANGING;
/

create PROCEDURE COUNT_DEPOSIT_PROFIT(p_account_id IN INT, p_owner IN INT) AS
    v_deposit_type INT;
    v_basic_amount FLOAT;
    v_recounts     INT;
    v_percentage   FLOAT;
    v_counter      INT := 1;
BEGIN
    -- Обработка NO_DATA_FOUND, если запись в DEPOSIT_STATE не найдена
    BEGIN
        SELECT DEPOSIT_TYPE, CURRENT_AMOUNT
        INTO v_deposit_type, v_basic_amount
        FROM DEPOSIT_STATE
        WHERE OWNER = p_owner
          AND ACCOUNT_FOR_PAY = p_account_id;

        -- Обработка NO_DATA_FOUND, если запись в DEPOSIT_CONDITIONS не найдена
        BEGIN
            SELECT TERMIN, PROCENTAGE_PER_YEAR
            INTO v_recounts, v_percentage
            FROM DEPOSIT_CONDITIONS
            WHERE ID = v_deposit_type;

            -- Проверка, что процент неотрицателен
            IF v_percentage < 0 THEN
                RAISE_APPLICATION_ERROR(-20001, 'Invalid percentage value');
            END IF;

            -- Обработка ZERO_DIVIDE, чтобы избежать деления на 0
            IF v_percentage = 0 THEN
                RAISE_APPLICATION_ERROR(-20002, 'Percentage cannot be zero');
            END IF;

            LOOP
                v_basic_amount := v_basic_amount + (v_basic_amount * (v_percentage / 100));
                v_counter := v_counter + 1;

                -- Выход из цикла при достижении v_recounts
                EXIT WHEN v_counter > v_recounts;
            END LOOP;

            DBMS_OUTPUT.PUT_LINE('Total amount at the end of the deposit term will be: ' || v_basic_amount);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('No data found in DEPOSIT_CONDITIONS for the specified deposit type');
            WHEN ZERO_DIVIDE THEN
                DBMS_OUTPUT.PUT_LINE('Percentage value is zero, causing division by zero');
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
        END;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No data found in DEPOSIT_STATE for the specified account and owner');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
    END;
END COUNT_DEPOSIT_PROFIT;
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



--fix
create or replace PROCEDURE CREATE_DEPOSIT(
    p_user_id IN INT,
    p_deposit_condition IN INT,
    p_amount IN NUMBER
) AS
    v_account_id INT;
    v_if_exists  int;
BEGIN
    select count(*) into v_if_exists from CLIENT_INFO where ID = p_user_id;
    -- Проверка на существование пользователя
    IF v_if_exists != 1 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Incorrect user id');
    END IF;

    if p_deposit_condition is not null and p_amount is not null then
        -- Вставка записи в таблицу CLIENT_ACCOUNT
        INSERT INTO CLIENT_ACCOUNT(owner, is_locked, account_type, balance)
        VALUES (p_user_id, 0, 1, p_amount);
    end if;

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

    DBMS_OUTPUT.PUT_LINE('Successfully created deposit deo client with id: ' || p_user_id);
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

--fix up

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
        RETURN;
    ELSE
        -- Delete the account
        DELETE
        FROM CLIENT_ACCOUNT
        WHERE OWNER = p_client_id
          AND ID = p_account_id;

        DBMS_OUTPUT.PUT_LINE('Account deleted successfully');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        RAISE_APPLICATION_ERROR(-20002, 'An error occurred: ' || SQLERRM);
END DELETE_ACCOUNT_FOR_CLIENT;
/

create PROCEDURE EXPORT_CLIENT_INFO(p_file_path IN VARCHAR2) AS
    v_json_file UTL_FILE.FILE_TYPE;
    v_max_id    NUMBER;
BEGIN
    -- Open the file for writing
    v_json_file := UTL_FILE.FOPEN('EXPORT_DIR', p_file_path, 'W');

    -- Get the maximum ID
    SELECT MAX(id) INTO v_max_id FROM CLIENT_INFO;

    -- Write the JSON array start
    UTL_FILE.PUT_LINE(v_json_file, '[');

    -- Cursor to fetch data from CLIENT_INFO
    FOR client_rec IN (SELECT * FROM CLIENT_INFO)
        LOOP
            -- Write JSON object for each row
            UTL_FILE.PUT_LINE(
                    v_json_file,
                    '{"name": "' || client_rec.name || '"' ||
                    ',"surname": "' || client_rec.surname || '"' ||
                    ',"thirdname": "' || client_rec.thirdname || '"' ||
                    ',"birth_date": "' || TO_CHAR(client_rec.birth_date, 'YYYY-MM-DD') || '"' ||
                    ',"phone_number": "' || client_rec.phone_number || '"}'
            );

            -- Write comma for all records except the last one
            IF client_rec.id != v_max_id THEN
                UTL_FILE.PUT_LINE(v_json_file, ',');
            END IF;
        END LOOP;

    -- Write the JSON array end
    UTL_FILE.PUT_LINE(v_json_file, ']');

    -- Close the file
    UTL_FILE.FCLOSE(v_json_file);
EXCEPTION
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END EXPORT_CLIENT_INFO;
/

create PROCEDURE get_user_info(p_user_id IN NUMBER)
AS
    v_first_name  VARCHAR2(50);
    v_second_name VARCHAR2(50);
    v_third_name  VARCHAR2(50);
    v_param_test  NUMBER;
BEGIN
    -- Validate that the provided parameter is a positive integer
    BEGIN
        v_param_test := TO_NUMBER(p_user_id);
        IF p_user_id IS NULL OR p_user_id <= 0 OR p_user_id != TRUNC(p_user_id) THEN
            RAISE_APPLICATION_ERROR(-20002, 'Invalid user ID provided.');
        END IF;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect type of parameter was passed');
    END;

    -- Select user information
    BEGIN
        SELECT CLIENT_INFO.NAME, CLIENT_INFO.SURNAME, CLIENT_INFO.THIRDNAME
        INTO v_first_name, v_second_name, v_third_name
        FROM CLIENT_INFO
        WHERE ID = p_user_id;

        -- Check if the user has a third name
        IF v_third_name IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('User ID: ' || p_user_id || ', First Name: ' || v_first_name ||
                                 ', Second Name: ' || v_second_name || ', Third Name: ' || v_third_name);
        ELSE
            DBMS_OUTPUT.PUT_LINE('User ID: ' || p_user_id || ', First Name: ' || v_first_name ||
                                 ', Second Name: ' || v_second_name || ', No Third Name');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'User with ID ' || p_user_id || ' not found.');
    END;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred for User ID ' || p_user_id || ': ' || SQLERRM);
END get_user_info;
/

create PROCEDURE IMPORT_CLIENT_INFO(p_file_path IN VARCHAR2) AS
    v_bfile      BFILE;
    v_json_data  CLOB;
    v_json_array JSON_ARRAY_T;
BEGIN
    -- Open the BFILE for reading
    v_bfile := BFILENAME('IMPORT_DIR', p_file_path);
    DBMS_LOB.FILEOPEN(v_bfile, DBMS_LOB.FILE_READONLY);

    -- Read the JSON data into a CLOB
    DBMS_LOB.CREATETEMPORARY(v_json_data, TRUE);
    DBMS_LOB.LOADFROMFILE(v_json_data, v_bfile, DBMS_LOB.GETLENGTH(v_bfile));

    -- Close the BFILE
    DBMS_LOB.FILECLOSE(v_bfile);

    -- Parse and insert JSON data into CLIENT_INFO
    v_json_array := JSON_ARRAY_T(v_json_data);

    FOR i IN 1..v_json_array.COUNT
        LOOP
            DECLARE
                client_rec CLIENT_INFO%ROWTYPE;
            BEGIN
                client_rec.name := v_json_array(i).name;
                client_rec.surname := v_json_array(i).surname;
                client_rec.thirdname := v_json_array(i).thirdname;
                client_rec.birth_date := TO_DATE(v_json_array(i).birth_date, 'YYYY-MM-DD');
                client_rec.phone_number := v_json_array(i).phone_number;

                -- Check for NULL values before inserting
                IF client_rec.name IS NOT NULL AND client_rec.surname IS NOT NULL AND
                   client_rec.birth_date IS NOT NULL AND client_rec.phone_number IS NOT NULL THEN
                    INSERT INTO CLIENT_INFO (name, surname, thirdname, birth_date, phone_number)
                    VALUES (client_rec.name, client_rec.surname, client_rec.thirdname, client_rec.birth_date,
                            client_rec.phone_number);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    -- Handle any errors for individual records
                    DBMS_OUTPUT.PUT_LINE('Error processing record ' || i || ': ' || SQLERRM);
            END;
        END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END IMPORT_CLIENT_INFO;
/

create or replace PROCEDURE LOGIN_CLIENT(
    p_login IN NVARCHAR2,
    p_password IN NVARCHAR2
) AS
    v_is_exists NUMBER;
BEGIN
    -- Check if the login and password exist in LOGIN_PASSWORD table
    SELECT COUNT(*)
    INTO v_is_exists
    FROM LOGIN_PASSWORD
    WHERE LOGIN = p_login
      AND PASSWORD = p_password;

    -- Handle the case when login or password is incorrect
    IF v_is_exists = 0 THEN
        -- Raise an exception for incorrect login or password
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect login or password');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Client logged in successfully');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
END LOGIN_CLIENT;
/

create PROCEDURE operations_amount(
    p_from_date IN DATE,
    p_to_date IN DATE,
    p_user_id IN INT,
    p_account_id IN INT
)
    IS
    v_operations_count INT;

BEGIN
    -- Проверка на отрицательное значение счета
    IF p_from_date IS NULL OR p_to_date IS NULL OR p_user_id IS NULL OR p_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters passed');
    END IF;

    SELECT COUNT(*)
    INTO v_operations_count
    FROM ACCOUNT_STATS
             INNER JOIN VYDRA_DBA.CLIENT_ACCOUNT ON ACCOUNT_STATS.ACCOUNT = CLIENT_ACCOUNT.ID
    WHERE ACTION_DATE <= p_to_date
      AND ACTION_DATE >= p_from_date
      AND p_user_id = CLIENT_ACCOUNT.OWNER
      AND p_account_id = CLIENT_ACCOUNT.ID;

    IF v_operations_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Number of operations for user ' || p_user_id || ' and account ' || p_account_id || ': ' ||
                             v_operations_count);
    ELSE
        RAISE_APPLICATION_ERROR(-20003, 'No data found for the specified criteria.');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'No data found for the specified criteria.');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
END operations_amount;
/

create or replace PROCEDURE refill_account(p_account_id IN NUMBER, p_amount IN NUMBER)
AS
    v_param_check NUMBER;
BEGIN
    -- Проверка на NULL
    BEGIN
        IF p_account_id IS NULL OR p_amount IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters passed');
        END IF;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters type');
    END;

    -- Попытка преобразования параметров к числовому типу
    BEGIN
        -- Проверка на отрицательное значение счета
        IF p_amount <= 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Amount must be greater than 0');
        END IF;

        -- Проверка на существование счета
        BEGIN
            SELECT COUNT(*) into v_param_check FROM CLIENT_ACCOUNT WHERE ID = p_account_id;
            IF v_param_check = 1 THEN
                UPDATE CLIENT_ACCOUNT SET BALANCE = BALANCE + p_amount WHERE ID = p_account_id;
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('Account refilled successfully');
            ELSE
                RAISE_APPLICATION_ERROR(-20004, 'Account does not exist');
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20001, 'An error occurred while checking account existence: ' || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
    END;
END refill_account;
/

create or replace PROCEDURE REGISTER_CLIENT(
    p_login IN nvarchar2,
    p_password IN NVARCHAR2,
    p_user_id IN INT
) AS
    v_client_count INT;
    v_login_taken  INT;
BEGIN
    -- Check if the client with the given ID exists
    SELECT COUNT(*)
    INTO v_client_count
    FROM CLIENT_ACCOUNT
    WHERE CLIENT_ACCOUNT.ID = p_user_id;

    -- Check if the login is already taken
    SELECT COUNT(*)
    INTO v_login_taken
    FROM LOGIN_PASSWORD
    WHERE p_login = LOGIN;

    -- Handle the case when the client with the given ID does not exist
    IF v_client_count = 0 AND v_login_taken = 0 THEN
        -- Insert login and password for the client
        INSERT INTO LOGIN_PASSWORD (LOGIN, PASSWORD, ID)
        VALUES (p_login, p_password, p_user_id);
        DBMS_OUTPUT.PUT_LINE('Client registered successfully');
    ELSIF v_login_taken > 0 THEN
        DBMS_OUTPUT.PUT_LINE('This login is already taken');
    ELSE
        -- Raise an exception when the client with the given ID does not exist
        RAISE_APPLICATION_ERROR(-20001, 'Incorrect ID: No such client');
        RETURN;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Handle the case when there is no data found during the SELECT statement
        RAISE_APPLICATION_ERROR(-20002, 'No such client');
    WHEN VALUE_ERROR THEN
        -- Handle the case when a value error occurs (e.g., incorrect parameter type)
        RAISE_APPLICATION_ERROR(-20003, 'Incorrect parameter type');
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        RAISE_APPLICATION_ERROR(-20004, 'An error occurred: ' || SQLERRM);
END REGISTER_CLIENT;
/

create or replace PROCEDURE transfer(
    p_sender_account IN NUMBER,
    p_receiver_account IN NUMBER,
    p_sender_id IN NUMBER,
    p_amount IN NUMBER
)
AS
    v_check_sender    NUMBER;
    v_check_receiver  NUMBER;
    v_check_parameter NUMBER;
BEGIN
    -- Validate that the parameters are valid numbers
    BEGIN
        v_check_parameter := TO_NUMBER(p_sender_account);
        v_check_parameter := TO_NUMBER(p_receiver_account);
        v_check_parameter := TO_NUMBER(p_sender_id);
        v_check_parameter := TO_NUMBER(p_amount);
    EXCEPTION
        WHEN VALUE_ERROR THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameter type');
    END;

    -- Check if any parameter is NULL
    IF p_sender_account IS NULL OR p_receiver_account IS NULL OR p_sender_id IS NULL OR p_amount IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'One or more parameters were not correctly passed.');
    END IF;

    -- Check sender account
    SELECT COUNT(*)
    INTO v_check_sender
    FROM CLIENT_ACCOUNT
    WHERE ID = p_sender_account
      AND OWNER = p_sender_id
      AND BALANCE >= p_amount;

    -- Check receiver account
    SELECT COUNT(*)
    INTO v_check_receiver
    FROM CLIENT_ACCOUNT
    WHERE ID = p_receiver_account;

    -- Validate sender and receiver
    IF v_check_sender = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid sender data.');
    END IF;

    IF v_check_receiver = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Invalid receiver data.');
    END IF;

    -- Update balances
    BEGIN
        UPDATE CLIENT_ACCOUNT
        SET BALANCE = BALANCE + p_amount
        WHERE ID = p_receiver_account;

        UPDATE CLIENT_ACCOUNT
        SET BALANCE = BALANCE - p_amount
        WHERE ID = p_sender_account;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'Error updating account balances: ' || SQLERRM);
    END;

    -- Insert into ACCOUNT_STATS
    BEGIN
        INSERT INTO ACCOUNT_STATS (account, action_date, action)
        VALUES (p_sender_account, SYSDATE, 'debit from account ' || p_sender_account || ' in amount: ' || p_amount);

        INSERT INTO ACCOUNT_STATS (account, action_date, action)
        VALUES (p_receiver_account, SYSDATE, 'refill ' || p_receiver_account || ' in amount: ' || p_amount);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'Error inserting into ACCOUNT_STATS: ' || SQLERRM);
    END;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Successfully transferred ' || p_amount ||
                         ' from account ' || p_sender_account ||
                         ' to ' || p_receiver_account);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
END transfer;
/

create or replace PROCEDURE withdrawal(p_account_id IN NUMBER, p_amount IN NUMBER)
AS
BEGIN
    -- Проверка на NULL
    BEGIN
        IF p_account_id IS NULL OR p_amount IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters passed');
        END IF;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters type');
    END;

    -- Проверка на отрицательное значение счета
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Amount must be greater than 0');
    END IF;

    -- Проверка на существование счета
    DECLARE
        v_account_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_account_count FROM CLIENT_ACCOUNT WHERE ID = p_account_id;

        IF v_account_count = 1 THEN
            UPDATE CLIENT_ACCOUNT SET BALANCE = BALANCE - p_amount WHERE ID = p_account_id;
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Money was withdrawn successfully');
        ELSE
            RAISE_APPLICATION_ERROR(-20004, 'Account does not exist');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'An error occurred while checking account existence: ' || SQLERRM);
    END;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
END withdrawal;
/