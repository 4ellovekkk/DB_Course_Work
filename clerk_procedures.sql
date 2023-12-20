CREATE OR REPLACE PROCEDURE CLIENT_CREATION(
    p_name IN NVARCHAR2(30),
    p_surname IN NVARCHAR2(30),
    p_thirdname IN NVARCHAR2(30) DEFAULT NULL,
    p_birth_date IN DATE,
    p_phone_number NVARCHAR2(30)
)
    IS
BEGIN
    -- Check if the phone number is a valid number
    BEGIN
        TO_NUMBER(p_phone_number);
    EXCEPTION
        WHEN VALUE_ERROR THEN
            RAISE_APPLICATION_ERROR(-20002, 'Invalid value for phone number');
    END;

    -- Insert into CLIENT_INFO
    BEGIN
        IF p_name IS NOT NULL AND p_surname IS NOT NULL AND p_birth_date IS NOT NULL AND p_phone_number IS NOT NULL and
           (extract(year from p_birth_date) <= (extract(year from sysdate) - 18)) and length(p_phone_number) = 13 and
           '+' in p_phone_number THEN
            INSERT INTO CLIENT_INFO(name, surname, thirdname, birth_date, phone_number)
            VALUES (p_name, p_surname, NVL(p_thirdname, ''), p_birth_date, p_phone_number);
        ELSE
            RAISE_APPLICATION_ERROR(-20002, 'Incorrect client data');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'An error occurred during client creation: ' || SQLERRM);
    END;
END client_creation;
/



create or replace PROCEDURE CLERK_LOGIN(
    p_login IN NVARCHAR2(30),
    p_password IN NVARCHAR2(30)
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




CREATE OR REPLACE PROCEDURE CLIENT_DELETE(p_client_id IN INT) AS
    v_is_client_exists INT;

    -- Exception for no rows found
    NO_ROWS_FOUND EXCEPTION;
    PRAGMA EXCEPTION_INIT (NO_ROWS_FOUND, -1403);

    -- Exception for too many rows found
    TOO_MANY_ROWS EXCEPTION;
    PRAGMA EXCEPTION_INIT (TOO_MANY_ROWS, -1422);

    -- Exception for general error during deletion
    DELETE_ERROR EXCEPTION;
    PRAGMA EXCEPTION_INIT (DELETE_ERROR, -20001);

BEGIN
    -- Check if the client exists
    BEGIN
        SELECT COUNT(*)
        INTO v_is_client_exists
        FROM CLIENT_INFO
        WHERE ID = p_client_id;

        IF v_is_client_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'No client found with the specified ID.');
        ELSIF v_is_client_exists > 1 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Multiple clients found with the same ID. Data integrity issue.');
        END IF;
    EXCEPTION
        WHEN NO_ROWS_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'No client found with the specified ID.');
        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(-20003, 'Multiple clients found with the same ID. Data integrity issue.');
    END;

    -- Delete the client
    BEGIN
        DELETE
        FROM CLIENT_INFO
        WHERE ID = p_client_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20001, 'An error occurred during client deletion: ' || SQLERRM);
        -- Optionally, you can log or handle the error as needed.
    END;
END CLIENT_DELETE;
/



CREATE OR REPLACE PROCEDURE CREATE_ACCOUNT_FOR_CLIENT(p_client_id IN INT, p_account_type IN INT) AS
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



CREATE OR REPLACE PROCEDURE DELETE_ACCOUNT_FOR_CLIENT(p_client_id IN INT, p_account_id IN INT) AS
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


CREATE OR REPLACE PROCEDURE CHANGE_CLIENT_ACCOUNT_TYPE(p_user_id IN INT, p_client_account IN INT) AS
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


