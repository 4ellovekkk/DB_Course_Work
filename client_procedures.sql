CREATE OR REPLACE PROCEDURE get_user_info(p_user_id IN NUMBER)
AS
    v_first_name  VARCHAR2(50);
    v_second_name VARCHAR2(50);
    v_third_name  VARCHAR2(50);
    v_param_test  number;
BEGIN
    v_param_test := to_number(p_user_id);
    -- Validate that the provided parameter is a positive integer
    IF p_user_id IS NOT NULL AND p_user_id > 0 AND p_user_id = TRUNC(p_user_id) THEN
        -- Select user information
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
    ELSE
        DBMS_OUTPUT.PUT_LINE('Invalid user ID provided.');
    END IF;

EXCEPTION
    when VALUE_ERROR then
        DBMS_OUTPUT.PUT_LINE('Incorrect type of parameter was passed');
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('User with ID ' || p_user_id || ' not found.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred for User ID ' || p_user_id || ': ' || SQLERRM);
END get_user_info;
/



CREATE OR REPLACE PROCEDURE check_balance(client_id IN NUMBER)
AS
    balance      NUMBER; -- Corrected the data type
    account_id   NUMBER; -- Corrected the data type
    v_param_test number;
BEGIN
    v_param_test := to_number(client_id);
    -- Removed unnecessary cast and adjusted the IF condition
    IF client_id IS NOT NULL AND client_id > 0 AND client_id = TRUNC(client_id) THEN
        SELECT ID, BALANCE INTO account_id, balance FROM CLIENT_ACCOUNT WHERE OWNER = client_id;
        DBMS_OUTPUT.PUT_LINE('Account id: ' || account_id || ' Balance: ' || balance);
    END IF;

EXCEPTION
    when VALUE_ERROR then
        DBMS_OUTPUT.PUT_LINE('Incorrect type of parameter was passed');
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('User with ID ' || client_id || ' not found.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred for User ID ' || client_id || ': ' || SQLERRM);
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
    IF p_account_id IS NULL OR p_from_date IS NULL OR p_to_date IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Invalid input parameters. Please provide valid values.');
        RETURN;
    END IF;

    -- Check if from_date is less than or equal to to_date
    IF p_from_date > p_to_date THEN
        DBMS_OUTPUT.PUT_LINE('Invalid date range. "From date" should be less than or equal to "To date".');
        RETURN;
    END IF;

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
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('Incorrect type of parameter was passed');
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No records found for the specified account and date range.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
    END;

    CLOSE c_account_history;
END account_history;



CREATE OR REPLACE PROCEDURE transfer(
    p_sender_account IN NUMBER,
    p_receiver_account IN NUMBER,
    p_sender_id IN NUMBER,
    p_amount IN NUMBER
)
AS
    v_check_sender    NUMBER;
    v_check_receiver  NUMBER;
    v_check_parameter number;
BEGIN
    v_check_parameter := to_number(p_sender_account);
    v_check_parameter := to_number(p_receiver_account);
    v_check_parameter := to_number(p_sender_id);
    v_check_parameter := to_number(p_amount);
    -- Check if any parameter is NULL
    IF p_sender_account IS NULL OR p_receiver_account IS NULL OR p_sender_id IS NULL OR p_amount IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('One or more parameters were not correctly passed.');
        RETURN;
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
        DBMS_OUTPUT.PUT_LINE('Invalid sender data.');
        RETURN;
    END IF;

    IF v_check_receiver = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Invalid receiver data.');
        RETURN;
    END IF;

    -- Update balances
    UPDATE CLIENT_ACCOUNT
    SET BALANCE = BALANCE + p_amount
    WHERE ID = p_receiver_account;

    UPDATE CLIENT_ACCOUNT
    SET BALANCE = BALANCE - p_amount
    WHERE ID = p_sender_account;

    insert into ACCOUNT_STATS (account, action_date, action)
    VALUES (p_sender_account, sysdate, 'debit from account ' || p_sender_account || ' in amount: ' || p_amount);
    insert into ACCOUNT_STATS (account, action_date, action)
    VALUES (p_receiver_account, sysdate, 'refill ' || p_receiver_account || ' in amount: ' || p_amount);
    commit;

    DBMS_OUTPUT.PUT_LINE('Successfully transferred ' || p_amount ||
                         ' from account ' || p_sender_account ||
                         ' to ' || p_receiver_account);
exception
    when VALUE_ERROR then
        DBMS_OUTPUT.PUT_LINE('Incorrect parameters type');
END transfer;
/



CREATE OR REPLACE PROCEDURE refill_account(p_account_id IN NUMBER, p_amount IN NUMBER)
AS
    v_param_check number;
BEGIN
    cast(v_param_check := p_account_id as number);
    cast(v_param_check := p_amount as number);
    -- Проверка на NULL
    IF p_account_id IS NULL OR p_amount IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Incorrect parameters passed');
        RETURN;
    END IF;

    -- Попытка преобразования параметров к числовому типу
    BEGIN
        -- Проверка на отрицательное значение счета
        IF p_amount <= 0 THEN
            DBMS_OUTPUT.PUT_LINE('Amount must be greater than 0');
            RETURN;
        END IF;

        -- Проверка на существование счета
        IF (SELECT COUNT(*) FROM CLIENT_ACCOUNT WHERE ID = p_account_id) = 1 THEN
            UPDATE CLIENT_ACCOUNT SET BALANCE = BALANCE + p_amount WHERE ID = p_account_id;
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('Account refilled successfully');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Account does not exist');
        END IF;
    EXCEPTION
        WHEN VALUE_ERROR THEN
            DBMS_OUTPUT.PUT_LINE('Incorrect parameters passed');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
    END;
END refill_account;
/



CREATE OR REPLACE PROCEDURE withdrawal(p_account_id IN NUMBER, p_amount IN NUMBER)
AS
BEGIN
    -- Проверка на NULL
    IF p_account_id IS NULL OR p_amount IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Incorrect parameters passed');
        RETURN;
    END IF;


    IF p_amount <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('Amount must be greater than 0');
        RETURN;
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
            DBMS_OUTPUT.PUT_LINE('Account does not exist');
        END IF;
    END;

EXCEPTION
    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE('Incorrect parameters passed');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END withdrawal;



CREATE or replace procedure accounts_amount(p_client_id in int)
as
    v_param_check_number int;
    v_amount             int;
begin
    v_param_check_number := to_number(p_client_id);
    select count(*) into v_amount from CLIENT_ACCOUNT where OWNER = p_client_id;
    DBMS_OUTPUT.PUT_LINE('Amount of accounts for current user is: ' || v_amount);
exception
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No records found for the specified account');
    when VALUE_ERROR then
        DBMS_OUTPUT.PUT_LINE('Incorrect parameters type');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
end accounts_amount;

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
    FOR r_value IN c_values_for_user
        LOOP
            v_total_sum := v_total_sum + r_value.amount; -- Use lowercase for cursor attribute
        END LOOP;

    IF v_total_sum IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Total sum for user ' || p_user_id || ': ' || v_total_sum);
    ELSE
        DBMS_OUTPUT.PUT_LINE('No data found for user ' || p_user_id);
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No data found for user ' || p_user_id);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
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
    SELECT COUNT(*)
    INTO v_operations_count
    FROM ACCOUNT_STATS
             INNER JOIN VYDRA_DBA.CLIENT_ACCOUNT ON ACCOUNT_STATS.ACCOUNT = CLIENT_ACCOUNT.ID
    WHERE ACTION_DATE <= p_to_date
      AND ACTION_DATE >= p_from_date
      AND p_user_id = CLIENT_ACCOUNT.OWNER
      AND p_account_id = CLIENT_ACCOUNT.ID; -- Corrected the condition for p_account_id

    DBMS_OUTPUT.PUT_LINE('Number of operations for user ' || p_user_id || ' and account ' || p_account_id || ': ' ||
                         v_operations_count);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No data found for the specified criteria.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END operations_amount;



CREATE OR REPLACE PROCEDURE REGISTER_CLIENT(
    p_login IN VARCHAR2(20),
    p_password IN VARCHAR2(30),
    p_user_id IN INT
) AS
    v_client_count INT;
    v_login_taken  int;
BEGIN
    -- Check if the client with the given ID exists
    SELECT COUNT(*)
    INTO v_client_count
    FROM CLIENT_ACCOUNT
    WHERE CLIENT_ACCOUNT.ID = p_user_id;

    select COUNT(*) into v_login_taken from LOGIN_PASSWORD where p_login = LOGIN;

    -- Handle the case when the client with the given ID does not exist
    IF v_client_count = 0 and v_login_taken = 0 THEN
        -- Insert login and password for the client
        INSERT INTO LOGIN_PASSWORD (LOGIN, PASSWORD, ID)
        VALUES (p_login, p_password, p_user_id);
        DBMS_OUTPUT.PUT_LINE('Client registered successfully');
    end if;
    if v_login_taken > 0 then
        DBMS_OUTPUT.PUT_LINE('This login was already taken');

    ELSE
        -- Raise an exception when the client with the given ID does not exist
        RAISE_APPLICATION_ERROR(-20001, 'Incorrect ID: No such client');
        return;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Handle the case when there is no data found during the SELECT statement
        DBMS_OUTPUT.PUT_LINE('No such client');
    WHEN VALUE_ERROR THEN
        -- Handle the case when a value error occurs (e.g., incorrect parameter type)
        DBMS_OUTPUT.PUT_LINE('Incorrect parameter type');
    WHEN OTHERS THEN
        -- Handle any other unexpected errors
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
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
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END LOGIN_CLIENT;
/



create or replace procedure CLIENT_INFO_CHANGING()
as
begin

end;