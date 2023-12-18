CREATE OR REPLACE PROCEDURE get_user_info(p_user_id IN NUMBER)
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


CREATE OR REPLACE PROCEDURE check_balance(client_id IN NUMBER)
AS
    balance      NUMBER;
    account_id   NUMBER;
    v_param_test NUMBER;
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
    BEGIN
        SELECT ID, BALANCE
        INTO account_id, balance
        FROM CLIENT_ACCOUNT
        WHERE OWNER = client_id;

        DBMS_OUTPUT.PUT_LINE('Account id: ' || account_id || ' Balance: ' || balance);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Account information not found for client ID ' || client_id);
    END;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred for client ID ' || client_id || ': ' || SQLERRM);
END check_balance;
/



CREATE OR REPLACE PROCEDURE account_history(
    p_account_id IN NUMBER,
    p_from_date IN DATE,
    p_to_date IN DATE
)
AS
    CURSOR c_account_history IS
        SELECT ACTION_DATE, ACTION, ACCOUNT
        FROM ACCOUNT_STATS
                 INNER JOIN VYDRA_DBA.CLIENT_ACCOUNT CA ON CA.ID = ACCOUNT_STATS.ACCOUNT
        WHERE CA.OWNER = p_account_id
          AND ACTION_DATE >= p_from_date
          AND ACTION_DATE <= p_to_date;
    v_operation_date DATE;
    v_operation      NVARCHAR2(50);
    v_account        INT;

BEGIN
    -- Validate input parameters
    BEGIN
        IF p_account_id IS NULL OR p_from_date IS NULL OR p_to_date IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Invalid input parameters. Please provide valid values.');
        END IF;

        -- Check if from_date is less than or equal to to_date
        IF p_from_date > p_to_date THEN
            RAISE_APPLICATION_ERROR(-20002,
                                    'Invalid date range. "From date" should be less than or equal to "To date".');
        END IF;
    EXCEPTION
        WHEN VALUE_ERROR THEN
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
CREATE OR REPLACE PROCEDURE transfer(
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



CREATE OR REPLACE PROCEDURE refill_account(p_account_id IN NUMBER, p_amount IN NUMBER)
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
            IF (SELECT COUNT(*) FROM CLIENT_ACCOUNT WHERE ID = p_account_id) = 1 THEN
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


CREATE OR REPLACE PROCEDURE withdrawal(p_account_id IN NUMBER, p_amount IN NUMBER)
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


CREATE OR REPLACE PROCEDURE accounts_amount(p_client_id IN INT)
AS
    v_param_check_number INT;
    v_amount             INT;
BEGIN
    -- Проверка на отрицательное значение счета
    BEGIN
        v_param_check_number := TO_NUMBER(p_client_id);
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
CREATE OR REPLACE PROCEDURE accounts_turnover(p_user_id IN INT)
AS
    v_total_sum NUMBER := 0;
    CURSOR c_values_for_user IS
        SELECT amount
        FROM ACCOUNT_STATS
                 INNER JOIN CLIENT_ACCOUNT ON ACCOUNT_STATS.ACCOUNT = CLIENT_ACCOUNT.ID
        WHERE OWNER = p_user_id
          AND AMOUNT IS NOT NULL;

BEGIN
    -- Проверка на отрицательное значение счета
    IF p_user_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'Incorrect parameters passed');
    END IF;

    FOR r_value IN c_values_for_user
        LOOP
            v_total_sum := v_total_sum + r_value.amount; -- Use lowercase for cursor attribute
        END LOOP;

    IF v_total_sum IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Total sum for user ' || p_user_id || ': ' || v_total_sum);
    ELSE
        RAISE_APPLICATION_ERROR(-20003, 'No data found for user ' || p_user_id);
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'No data found for user ' || p_user_id);
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
END accounts_turnover;
/

CREATE OR REPLACE PROCEDURE operations_amount(
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
CREATE OR REPLACE PROCEDURE REGISTER_CLIENT(
    p_login IN VARCHAR2(20),
    p_password IN VARCHAR2(30),
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
CREATE OR REPLACE PROCEDURE LOGIN_CLIENT(
    p_login IN NVARCHAR2(30),
    p_password IN NVARCHAR2(30)
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


CREATE OR REPLACE PROCEDURE CLIENT_INFO_CHANGING(
    p_client_id IN INT,
    p_name IN NVARCHAR2(50),
    p_surname IN NVARCHAR2(50),
    p_thirdname IN NVARCHAR2(50),
    p_phone_number IN NVARCHAR2(50)
) AS
    v_phone_check NUMBER;

    -- Exception for invalid phone number
    INVALID_PHONE EXCEPTION;
    PRAGMA EXCEPTION_INIT (INVALID_PHONE, -6502);

    -- Exception for no rows updated
    NO_ROWS_UPDATED EXCEPTION;
    PRAGMA EXCEPTION_INIT (NO_ROWS_UPDATED, -1422);
BEGIN
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
    EXCEPTION
        WHEN NO_ROWS_UPDATED THEN
            DBMS_OUTPUT.PUT_LINE('No rows updated for PHONE NUMBER');
        WHEN INVALID_PHONE THEN
            DBMS_OUTPUT.PUT_LINE('Invalid phone number');
    END;
END CLIENT_INFO_CHANGING;
/