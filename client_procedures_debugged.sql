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

create PROCEDURE get_user_info(p_user_id IN NUMBER)
AS
    v_first_name   nVARCHAR2(50);
    v_second_name  nVARCHAR2(50);
    v_third_name   nVARCHAR2(50);
    v_phone_number nvarchar2(50);
    v_birth_date   date;
    v_param_test   NUMBER;
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
        SELECT CLIENT_INFO.NAME,
               CLIENT_INFO.SURNAME,
               CLIENT_INFO.THIRDNAME,
               CLIENT_INFO.PHONE_NUMBER,
               CLIENT_INFO.BIRTH_DATE
        INTO v_first_name, v_second_name, v_third_name, v_phone_number, v_birth_date
        FROM CLIENT_INFO
        WHERE ID = p_user_id;

        -- Check if the user has a third name
        IF v_third_name IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('User ID: ' || p_user_id || ', First Name: ' || v_first_name ||
                                 ', Second Name: ' || v_second_name || ', Third Name: ' || v_third_name ||
                                 ' Phone number: +' || v_phone_number || ' Birth date: ' || to_char(v_birth_date));
        ELSE
            DBMS_OUTPUT.PUT_LINE('User ID: ' || p_user_id || ', First Name: ' || v_first_name ||
                                 ', Second Name: ' || v_second_name || ', No Third Name' || ' Phone number: +' ||
                                 v_phone_number || ' Birth date: ' || to_char(v_birth_date));
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

create PROCEDURE LOGIN_CLIENT(
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
AS
    v_operations_count INT;
BEGIN
    -- Проверка на отрицательное значение счета
    IF p_from_date IS NULL OR p_to_date IS NULL OR p_user_id IS NULL OR p_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters passed');
    END IF;

    SELECT count(*)
    into v_operations_count
    FROM ACCOUNT_STATS
             INNER JOIN VYDRA_DBA.CLIENT_ACCOUNT CA ON CA.ID = ACCOUNT_STATS.ACCOUNT
    WHERE CA.OWNER = p_user_id
      and ACCOUNT_STATS.ACCOUNT = p_account_id
      AND ACTION_DATE >= p_from_date
      AND ACTION_DATE <= p_to_date;

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

create PROCEDURE refill_account(p_account_id IN NUMBER, p_amount IN NUMBER)
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
            SELECT COUNT(*) into v_param_check FROM CLIENT_ACCOUNT WHERE ID = p_account_id and IS_LOCKED = 0;
            IF v_param_check = 1 THEN
                UPDATE CLIENT_ACCOUNT SET BALANCE = BALANCE + p_amount WHERE ID = p_account_id;
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('Account refilled successfully');
            ELSE
                RAISE_APPLICATION_ERROR(-20004, 'Account does not exist or it is locked');
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

create PROCEDURE REGISTER_CLIENT(
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
    FROM CLIENT_INFO
    WHERE CLIENT_INFO.ID = p_user_id;

    -- Check if the login is already taken
    SELECT COUNT(*)
    INTO v_login_taken
    FROM LOGIN_PASSWORD
    WHERE p_login = LOGIN;

    -- Handle the case when the client with the given ID does not exist
    IF v_client_count != 0 AND v_login_taken = 0 THEN
        -- Insert login and password for the client
        INSERT INTO LOGIN_PASSWORD (LOGIN, PASSWORD, ID)
        VALUES (p_login, p_password, p_user_id);
        DBMS_OUTPUT.PUT_LINE('Client registered successfully');
    ELSIF v_login_taken > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'This login is already taken');
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

create PROCEDURE transfer(
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
      AND BALANCE >= p_amount
      and IS_LOCKED = 0;

    -- Check receiver account
    SELECT COUNT(*)
    INTO v_check_receiver
    FROM CLIENT_ACCOUNT
    WHERE ID = p_receiver_account
      and IS_LOCKED = 0;

    -- Validate sender and receiver
    IF v_check_sender = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid sender data or locked account');
    END IF;

    IF v_check_receiver = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Invalid receiver data or locked account');
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
        INSERT INTO ACCOUNT_STATS (account, action_date, action, AMOUNT)
        VALUES (p_sender_account, SYSDATE, 3, p_amount);

        INSERT INTO ACCOUNT_STATS (account, action_date, action, AMOUNT)
        VALUES (p_receiver_account, SYSDATE, 1, p_amount);
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

create PROCEDURE withdrawal(p_account_id IN NUMBER, p_amount IN NUMBER, p_client_id in int)
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
        SELECT COUNT(*)
        INTO v_account_count
        FROM CLIENT_ACCOUNT
        WHERE ID = p_account_id and IS_LOCKED = 0 and OWNER = p_client_id;

        IF v_account_count = 1 THEN
            UPDATE CLIENT_ACCOUNT SET BALANCE = BALANCE - p_amount WHERE ID = p_account_id;
            insert into ACCOUNT_STATS(account, action_date, action, amount) values (p_account_id, sysdate, 2, p_amount);
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Money was withdrawn successfully');
        ELSE
            RAISE_APPLICATION_ERROR(-20004, 'Account does not exist or it is locked');
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

